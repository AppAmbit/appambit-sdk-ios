import UIKit
import Foundation
import Network

@objcMembers
public final class AppAmbit: NSObject, @unchecked Sendable {
    private nonisolated(unsafe) static var _instance: AppAmbit?
    private static let instanceQueue = Queues.state

    let monitor = NWPathMonitor()
    private var lastPathStatus: NWPath.Status?
    private var lastSendAllAt: CFAbsoluteTime = 0
    private let minSendInterval: CFAbsoluteTime = 1.0

    private static var shared: AppAmbit? {
        instanceQueue.sync { _instance }
    }

    private let appKey: String
    private var isCreatingConsumer = false
    private var consumerCreationCallbacks: [(@Sendable (Bool) -> Void)] = []
    private var reachability: ReachabilityService?

    private init(appKey: String) {
        self.appKey = appKey
        super.init()
        CrashHandler.shared.register()
        setupLifecycleObservers()
    }

    public static func start(appKey: String, completion: @escaping @Sendable () -> Void = {}) {
        instanceQueue.async {
            if _instance != nil {
                AppAmbitLogger.log(message: "SDK already started")
                DispatchQueue.main.async { completion() }
                return
            }

            let instance = AppAmbit(appKey: appKey)
            _instance = instance

            instance.onStart {
                DispatchQueue.main.async { completion() }
            }
        }
    }

    private func setupLifecycleObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        monitor.cancel()
        AppAmbitLogger.log(message: "Deinit called - Observers removed")
    }

    @objc private func appDidBecomeActive() {
        Self.instanceQueue.async { [weak self] in self?.onResume() }
    }

    @objc private func appWillResignActive() {
        Self.instanceQueue.async { [weak self] in self?.onSleep() }
    }

    @objc private func appDidEnterBackground() {
        Self.instanceQueue.async { [weak self] in self?.onSleep() }
    }

    @objc private func appWillEnterForeground() {
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.tokenIsValid() {
                self.getNewToken { success in
                    if success { self.sendAllPendingData() }
                }
            } else {
                self.sendAllPendingData()
            }
        }
    }

    @objc private func appWillTerminate() {
        Self.instanceQueue.async { [weak self] in self?.onEnd() }
    }

    // MARK: - Services
    private func initializeServices() {
        let apiService = ServiceContainer.shared.apiService
        _ = ServiceContainer.shared.appInfoService
        let storageService = ServiceContainer.shared.storageService
        let reachabilityService = ServiceContainer.shared.reachabilityService

        Analytics.initialize(apiService: apiService, storageService: storageService)
        SessionManager.initialize(apiService: apiService, storageService: storageService)
        self.reachability = reachabilityService

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            if self.lastPathStatus == path.status { return }
            self.lastPathStatus = path.status

            if path.status == .satisfied {
                if !self.tokenIsValid() {
                    self.getNewToken { success in
                        guard success else { return }
                        SessionManager.sendEndSessionFromDatabase { _ in
                            SessionManager.sendStartSessionIfExist { _ in
                                Crashes.shared.loadCrashFileIfExists { _ in
                                    self.sendAllPendingData()
                                }
                            }
                        }
                    }
                } else {
                    SessionManager.sendEndSessionFromDatabase { _ in
                        SessionManager.sendStartSessionIfExist { _ in
                            Crashes.shared.loadCrashFileIfExists { _ in
                                self.sendAllPendingData()
                            }
                        }
                    }
                }
            }
        }
        monitor.start(queue: Self.instanceQueue)
    }

    // MARK: - Main startup
    private func onStart(completion: @escaping @Sendable () -> Void) {
        initializeServices()

        initializeConsumer {
            Crashes.shared.loadCrashFileIfExists { _ in
                self.sendAllPendingData()
                completion()
            }
        }
    }

    private func initializeConsumer(completion: @escaping @Sendable () -> Void) {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveSessionEndToDatabaseIfExist()
        }

        getNewToken { success in
            guard success else {
                AppAmbitLogger.log(message: "Invalid token, aborting boot")
                completion()
                return
            }

            if Analytics.isManualSessionEnabled {
                completion()
                return
            }

            SessionManager.sendEndSessionFromDatabase { _ in
                SessionManager.sendEndSessionFromFile { _ in
                    SessionManager.startSession { _ in
                        completion()
                    }
                }
            }
        }
    }

    private func getNewToken(completion: @escaping @Sendable (Bool) -> Void) {
        Self.instanceQueue.async {
            if self.isCreatingConsumer {
                self.consumerCreationCallbacks.append(completion)
                return
            }

            self.isCreatingConsumer = true
            self.consumerCreationCallbacks.append(completion)

            do {
                ConsumerService.shared.updateAppKeyIfNeeded(self.appKey)
                if let consumerId = try ServiceContainer.shared.storageService.getConsumerId(),
                   !consumerId.isEmpty {
                    ServiceContainer.shared.apiService.getNewToken { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                } else {
                    ConsumerService.shared.createConsumer { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                }
            } catch {
                AppAmbitLogger.log(message: "Error reading consumer Id: \(error)")
                self.handleTokenResult(errorType: .unknown)
            }
        }
    }

    private func handleTokenResult(errorType: ApiErrorType) {
        let success = (errorType == .none)
        Self.instanceQueue.async {
            self.isCreatingConsumer = false
            let callbacks = self.consumerCreationCallbacks
            self.consumerCreationCallbacks.removeAll()
            callbacks.forEach { $0(success) }
        }
    }

    // MARK: - Resume / Sleep / End
    private func onResume() {
        if !tokenIsValid() {
            getNewToken { [weak self] _ in self?.continueOnResume() }
        } else {
            continueOnResume()
        }
    }

    private func continueOnResume() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.removeSavedEndSession()
        }
        Crashes.shared.loadCrashFileIfExists { _ in self.sendAllPendingData() }
    }

    private func sendAllPendingData() {
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastSendAllAt < minSendInterval { return }
        lastSendAllAt = now

        SessionManager.sendBatchSessions { _ in
            Analytics.sendBatchEvents()
            Crashes.sendBatchLogs()
        }
    }

    private func onSleep() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSession()
        }
    }

    private func onEnd() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSession()
        }
    }

    private func tokenIsValid() -> Bool {
        guard let token = ServiceContainer.shared.apiService.token else { return false }
        return !token.isEmpty
    }
}
