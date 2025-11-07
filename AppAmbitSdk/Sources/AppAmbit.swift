import UIKit
import Foundation
import Network
import ObjectiveC.runtime

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

    private var didSendOnStart = false

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
            let afterTokenReady: @Sendable () -> Void = {
                Crashes.shared.loadCrashFileIfExists { _ in
                    BreadcrumbManager.loadBreadcrumbsFromFile { _ in
                        self.sendAllPendingData()
                    }
                }
            }

            if !self.tokenIsValid() {
                self.getNewToken { success in
                    if success { afterTokenReady() }
                }
            } else {
                afterTokenReady()
            }
        }
    }
    @objc private func appWillTerminate() {
        Self.instanceQueue.async { [weak self] in self?.onEnd() }
    }

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
                guard self.didSendOnStart else { return }

                let afterTokenReady: @Sendable () -> Void = {
                    guard SessionManager.isSessionActive else { return }

                    SessionManager.sendEndSessionFromDatabase { _ in
                        SessionManager.sendStartSessionIfExist { _ in
                            Crashes.shared.loadCrashFileIfExists { _ in
                                BreadcrumbManager.loadBreadcrumbsFromFile { _ in
                                    BreadcrumbManager.addAsync(name: BreadcrumbsConstants.online)

                                    self.sendAllPendingData()
                                }
                            }
                        }
                    }
                }

                if !self.tokenIsValid() {
                    self.getNewToken { success in
                        guard success else { return }
                        afterTokenReady()
                    }
                } else {
                    afterTokenReady()
                }
            } else {
                guard SessionManager.isSessionActive else {
                    AppAmbitLogger.log(message: "Skipping Offline breadcrumb: no active session.")
                    return
                }

                BreadcrumbManager.saveFile(name: BreadcrumbsConstants.offline)
                AppAmbitLogger.log(message: "Internet connection is not available.")
            }
        }
        monitor.start(queue: Self.instanceQueue)
    }

    private func onStart(completion: @escaping @Sendable () -> Void) {
        initializeServices()

        initializeConsumer {
            BreadcrumbManager.addAsync(name: BreadcrumbsConstants.onStart)
            self.didSendOnStart = true

            Crashes.shared.loadCrashFileIfExists { _ in
                BreadcrumbManager.loadBreadcrumbsFromFile { _ in
                    self.sendAllPendingData()
                    completion()
                }
            }
        }
    }

    private func initializeConsumer(completion: @escaping @Sendable () -> Void) {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveSessionEndToDatabaseIfExist()
        }

        getNewToken { success in
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

    private func onResume() {
        let shouldSendResume = hasSlept
        hasSlept = false

        if !tokenIsValid() {
            getNewToken { [weak self] _ in
                guard let self else { return }
                self.continueOnResume(shouldSendResume)
            }
        } else {
            continueOnResume(shouldSendResume)
        }
    }

    private func continueOnResume(_ shouldSendResume: Bool) {
        if !Analytics.isManualSessionEnabled {
            SessionManager.removeSavedEndSession()
        }
        Crashes.shared.loadCrashFileIfExists { [weak self] _ in
            BreadcrumbManager.loadBreadcrumbsFromFile { [weak self] _ in
                guard let self = self else { return }
                if shouldSendResume {
                    BreadcrumbManager.addAsync(name: BreadcrumbsConstants.onResume)
                }
                
                self.sendAllPendingData()
            }
        }
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
            BreadcrumbManager.saveFile(name: BreadcrumbsConstants.onPause)
        }
    }

    private func onEnd() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSession()
            BreadcrumbManager.addAsync(name: BreadcrumbsConstants.onDestroy)
        }
    }

    private func tokenIsValid() -> Bool {
        guard let token = ServiceContainer.shared.apiService.token else { return false }
        return !token.isEmpty
    }
}

@MainActor
private enum AmbitAssoc { static var tracked: UInt8 = 0 }

fileprivate extension UIViewController {
    @MainActor private var isWindowRoot: Bool {
        (view.window?.rootViewController === self) || (parent == nil && presentingViewController == nil)
    }

    @MainActor private var isTabRootHost: Bool {
        if let nav = navigationController, nav.viewControllers.first === self { return true }
        return parent is UITabBarController
    }

    @MainActor private var isPushedInsideNavNow: Bool {
        guard let nav = navigationController else { return false }
        return nav.viewControllers.count > 1 && nav.topViewController === self
    }

    @MainActor private var isPresentedModallyNow: Bool {
        presentingViewController != nil
    }

    @MainActor private var shouldTrackAppear: Bool {
        if self is UINavigationController || self is UITabBarController { return false }
        if isWindowRoot { return false }
        if isTabRootHost { return false }
        if isPushedInsideNavNow { return true }
        if isPresentedModallyNow { return true }
        return false
    }

    @MainActor private var didTrackAppear: Bool {
        get {
            withUnsafePointer(to: &AmbitAssoc.tracked) { key in
                (objc_getAssociatedObject(self, key) as? Bool) == true
            }
        }
        set {
            withUnsafePointer(to: &AmbitAssoc.tracked) { key in
                objc_setAssociatedObject(self, key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

    @MainActor @objc dynamic func swizzled_viewDidAppear(_ animated: Bool) {
        self.swizzled_viewDidAppear(animated)
        guard shouldTrackAppear else { return }
        didTrackAppear = true
        let screenName = String(describing: type(of: self))
        BreadcrumbManager.addAsync(name: BreadcrumbsConstants.onAppear)
        print(screenName)
    }

    @MainActor @objc dynamic func swizzled_viewDidDisappear(_ animated: Bool) {
        self.swizzled_viewDidDisappear(animated)
        guard didTrackAppear else { return }
        didTrackAppear = false
        BreadcrumbManager.addAsync(name: BreadcrumbsConstants.onDisappear)
    }

    static func swizzleMethod(original: Selector, swizzled: Selector) {
        guard let m1 = class_getInstanceMethod(Self.self, original),
              let m2 = class_getInstanceMethod(Self.self, swizzled) else { return }
        method_exchangeImplementations(m1, m2)
    }
}
