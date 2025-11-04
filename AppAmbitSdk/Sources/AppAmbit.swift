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
    private var objcCompletion: (() -> Void)?


    private static var shared: AppAmbit? {
        instanceQueue.sync { _instance }
    }

    private let appKey: String
    private var isCreatingConsumer = false
    private var hasSlept = false
    private var consumerCreationCallbacks: [(@Sendable (Bool) -> Void)] = []
    private var reachability: ReachabilityService?

    private init(appKey: String) {
        self.appKey = appKey
        super.init()
        CrashHandler.shared.register()
        setupLifecycleObservers()
        setupViewControllerLifecycleTracking()
    }
   
    @objc private func fireObjCCompletion() {
        let cb = objcCompletion
        objcCompletion = nil
        cb?()
    }

    @nonobjc
    public static func start(appKey: String, completion: @escaping () -> Void = {}) {
        instanceQueue.sync {
            if let inst = _instance {
                inst.objcCompletion = completion
                inst.performSelector(onMainThread: #selector(AppAmbit.fireObjCCompletion), with: nil, waitUntilDone: false)
                return
            }

            let instance = AppAmbit(appKey: appKey)
            _instance = instance
            instance.objcCompletion = completion

            instance.onStart {
                instance.performSelector(onMainThread: #selector(AppAmbit.fireObjCCompletion), with: nil, waitUntilDone: false)
            }
        }
    }

    @objc(start:)
    public class func startObjC(_ appKey: String) {
        start(appKey: appKey, completion: {})
    }

    @objc(start:completion:)
    public class func startObjC(_ appKey: String, completion: @escaping () -> Void) {
        start(appKey: appKey, completion: completion)
    }

    private func setupLifecycleObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    private func setupViewControllerLifecycleTracking() {
        DispatchQueue.main.async {
            let originalDidAppear = #selector(UIViewController.viewDidAppear(_:))
            let swizzledDidAppear = #selector(UIViewController.swizzled_viewDidAppear(_:))
            
            let originalDidDisappear = #selector(UIViewController.viewDidDisappear(_:))
            let swizzledDidDisappear = #selector(UIViewController.swizzled_viewDidDisappear(_:))

            UIViewController.swizzleMethod(original: originalDidAppear, swizzled: swizzledDidAppear)
            UIViewController.swizzleMethod(original: originalDidDisappear, swizzled: swizzledDidDisappear)
        }
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
        BreadcrumbManager.initialize(apiService: apiService, storageService: storageService)

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
                            BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.online)
                            Crashes.shared.loadCrashFileIfExists { _ in
                                self.sendAllPendingData()
                            }
                        }
                    }
                }
                BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.online)
            } else {
                BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.offline)
                AppAmbitLogger.log(message: "Internet connection is not available.")
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
        BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.appStart)
    }

    private func initializeConsumer(completion: @escaping @Sendable () -> Void) {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveSessionEndToDatabaseIfExist()
            BreadcrumbManager.sendBreadcrumbsToDatabaseIfExist()
        }

        getNewToken { success in

            if Analytics.isManualSessionEnabled {
                completion()
                return
            }

            SessionManager.sendEndSessionFromDatabase { _ in
                SessionManager.sendEndSessionFromFile { _ in
                    SessionManager.startSession { _ in
                        BreadcrumbManager.shared.flushPendingBreadcrumbs()
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
        hasSlept = false
        if !Analytics.isManualSessionEnabled {
            BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.appResume)
        }
        if !tokenIsValid() {
            getNewToken { [weak self] _ in self?.continueOnResume() }
        } else {
            continueOnResume()
        }
    }

    private func continueOnResume() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.removeSavedEndSession()
            BreadcrumbManager.removeLastDestroyBreadcrumb()
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
            BreadcrumbManager.sendBatchBreadcrumbs()
        }
    }

    private func onSleep() {
        if hasSlept { return }
        hasSlept = true
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSession()
            BreadcrumbManager.saveBreadcrumbFile(breadcrumbName: BreadcrumbsConstants.appSleep)
            BreadcrumbManager.saveBreadcrumbFile(breadcrumbName: BreadcrumbsConstants.appDestroy)
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

private extension UIViewController {

    private var isValidScreen: Bool {
        let screenName = String(describing: type(of: self))
        
        let excludedPrefixes = [
            "UI",
            "_UI",
            "WK",
            "Tab",
            "PlatformAlertController"
        ]
        
        return excludedPrefixes.allSatisfy { prefix in
            !screenName.hasPrefix(prefix)
        }
    }
    
    @objc func swizzled_viewDidAppear(_ animated: Bool) {
        self.swizzled_viewDidAppear(animated)

        guard isValidScreen else { return }
        
        let screenName = String(describing: type(of: self))
        BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.appAppear)
        print(screenName)
    }

    @objc func swizzled_viewDidDisappear(_ animated: Bool) {
        self.swizzled_viewDidDisappear(animated)

        guard isValidScreen else { return }
        
        BreadcrumbManager.shared.addAsync(name: BreadcrumbsConstants.appDisappear)
    }

    static func swizzleMethod(original: Selector, swizzled: Selector) {
        guard let originalMethod = class_getInstanceMethod(Self.self, original),
              let swizzledMethod = class_getInstanceMethod(Self.self, swizzled) else { return }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
