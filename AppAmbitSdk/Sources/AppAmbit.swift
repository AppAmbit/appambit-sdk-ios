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
    private var consumerCreationCallbacks: [(Bool) -> Void] = []
    private var reachability: ReachabilityService?

    private init(appKey: String) {
        self.appKey = appKey
        super.init()
        CrashHandler.shared.register()
        setupLifecycleObservers()
        onStart()
    }

    public static func start(appKey: String) {
        instanceQueue.async {
            if _instance == nil {
                _instance = AppAmbit(appKey: appKey)
            } else {
                AppAmbitLogger.log(message: "SDK already started")
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
        AppAmbitLogger.log(message: "appDidBecomeActive")
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.onResume()
        }
    }

    @objc private func appWillResignActive() {
        AppAmbitLogger.log(message: "appWillResignActive")
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }

    @objc private func appDidEnterBackground() {
        AppAmbitLogger.log(message: "appDidEnterBackground")
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }

    @objc private func appWillEnterForeground() {
        AppAmbitLogger.log(message: "appWillEnterForeground")
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            if !tokenIsValid() {
                self.getNewToken { success in
                    if success { self.sendAllPendingData() }
                }
            } else {
                self.sendAllPendingData()
            }
        }
    }

    @objc private func appWillTerminate() {
        AppAmbitLogger.log(message: "appWillTerminate")
        Self.instanceQueue.async { [weak self] in
            guard let self = self else { return }
            self.onEnd()
        }
    }

    private func initializeServices() {
        let apiService = ServiceContainer.shared.apiService
        _ = ServiceContainer.shared.appInfoService
        let storageService = ServiceContainer.shared.storageService
        let reachabilityService = ServiceContainer.shared.reachabilityService

        Analytics.initialize(apiService: apiService, storageService: storageService)
        SessionManager.initialize(apiService: apiService, storageService: storageService)

        self.reachability = reachabilityService

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if self.lastPathStatus == path.status { return }
            self.lastPathStatus = path.status
            
            if path.status == .satisfied {
                AppAmbitLogger.log(message: "Connected via \(path.debugDescription)")
                
                if !self.tokenIsValid() {
                    self.getNewToken { success in
                        guard success else { return }
                        
                        SessionManager.sendEndSessionFromDatabase { _ in
                            SessionManager.sendStartSessionIfExist { _ in
                                Crashes.shared.loadCrashFileIfExists { _ in
                                    self.sendAllPendingData();
                                }
                            }
                        }
                    }
                } else {
                    SessionManager.sendEndSessionFromDatabase { _ in
                        SessionManager.sendStartSessionIfExist { _ in
                            Crashes.shared.loadCrashFileIfExists { _ in
                                self.sendAllPendingData();
                            }
                        }
                    }
                }
            } else {
                AppAmbitLogger.log(message: "Internet connection is not available.")
            }
        }
        monitor.start(queue: Self.instanceQueue)
    }

    private func initializeConsumer() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveSessionEndToDatabaseIfExist()
        }
        getNewToken { _ in
            if Analytics.isManualSessionEnabled { return }
            
            SessionManager.sendEndSessionFromDatabase { error in
                SessionManager.sendEndSessionFromFile {error in
                    SessionManager.startSession { _ in
                        //Crashes.shared.loadCrashFileIfExists()
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
                if let consumerId = try ServiceContainer.shared.storageService.getConsumerId(), !consumerId.isEmpty {
                    ServiceContainer.shared.apiService.getNewToken { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                } else {
                    ConsumerService.shared.createConsumer() { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                }
            } catch {
                AppAmbitLogger.log(message: "Error reading consumerId: \(error)")
                self.handleTokenResult(errorType: .unknown)
            }
        }
    }

    private func handleTokenResult(errorType: ApiErrorType) {
        let success = (errorType == .none)
        Self.instanceQueue.async {
            self.isCreatingConsumer = false
            let callbacks = self.consumerCreationCallbacks
            self.consumerCreationCallbacks = []
            callbacks.forEach { $0(success) }
        }
    }

    private func onStart() {
        initializeServices()
        initializeConsumer()
        
        Crashes.shared.loadCrashFileIfExists { _ in
            self.sendAllPendingData();
        }
    }

    private func onResume() {
        if !tokenIsValid() {
            getNewToken { [weak self] _ in
                guard let self = self else { return }
                self.continueOnResume()
            }
        } else {
            continueOnResume()
        }
    }

    private func continueOnResume() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.removeSavedEndSession()
        }
        
        Crashes.shared.loadCrashFileIfExists { _ in
            self.sendAllPendingData();
        }
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
