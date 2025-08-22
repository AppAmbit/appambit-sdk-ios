import UIKit
import Foundation

public final class AppAmbit: @unchecked Sendable {
    private nonisolated(unsafe) static var _instance: AppAmbit?
    private static let instanceQueue = DispatchQueue(label: "com.appambit.instance.queue")
    
    public static var shared: AppAmbit? {
        instanceQueue.sync { _instance }
    }
    
    private let appKey: String
    private let workerQueue = DispatchQueue(label: "com.appambit.workerQueue")
    private let consumerCreationQueue = DispatchQueue(label: "com.appambit.consumerCreationQueue")
    private var isCreatingConsumer = false
    private var consumerCreationCallbacks: [(Bool) -> Void] = []
    private static let consumerCreationQueue = DispatchQueue(label: "com.appambit.consumerCreationQueue")
    private var reachability: ReachabilityService?
    
    private init(appKey: String) {
        AppAmbitLogger.log(message: "INIT")
        self.appKey = appKey
        CrashHandler.shared.register()
        setupLifecycleObservers()
        onStart()
    }
    
    public static func start(appKey: String) {
        instanceQueue.async {
            if _instance == nil {
                _instance = AppAmbit(appKey: appKey)
                AppAmbitLogger.log(message: "SDK started with appKey: \(appKey)")
            } else {
                AppAmbitLogger.log(message: "SDK already started")
            }
        }
    }
    
    private func setupLifecycleObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(appDidBecomeActive),
                       name: UIApplication.didBecomeActiveNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appWillResignActive),
                       name: UIApplication.willResignActiveNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appDidEnterBackground),
                       name: UIApplication.didEnterBackgroundNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appWillEnterForeground),
                       name: UIApplication.willEnterForegroundNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(appWillTerminate),
                       name: UIApplication.willTerminateNotification,
                       object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        reachability?.stop()
        AppAmbitLogger.log(message: "Deinit called - Observers removed")
    }
    
    @objc private func appDidBecomeActive() {
        AppAmbitLogger.log(message: "appDidBecomeActive")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onResume()
        }
    }
    
    @objc private func appWillResignActive() {
        AppAmbitLogger.log(message: "appWillResignActive")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }
    
    @objc private func appDidEnterBackground() {
        AppAmbitLogger.log(message: "appDidEnterBackground")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }
    
    @objc private func appWillEnterForeground() {
        AppAmbitLogger.log(message: "appWillEnterForeground")
        workerQueue.async { [weak self] in
            AppAmbitLogger.log(message: "onResume: GetNewToken, removeSavedEndSessionToFile, SendBatchLogs, SendBatchEvents")
            
            guard let self = self else { return }
            
            if !tokenIsValid() {
                self.getNewToken { success in
                    if success {
                        self.sendAllPendingData()
                    }
                }
            } else {
                self.sendAllPendingData()
            }
        }
    }
    
    @objc private func appWillTerminate() {
        AppAmbitLogger.log(message: "appWillTerminate")
        workerQueue.async { [weak self] in
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

        do {
            try reachabilityService.startMonitoring { [weak self] status in
                self?.handleConnectionChange(status: status)
            }
        } catch {
            AppAmbitLogger.log(message: "Error starting network monitoring: \(error.localizedDescription)")
        }
    }

    @Sendable
    func handleConnectionChange(status: ReachabilityService.NetworkStatus) {
        switch status {
        case .connected(let type):
            AppAmbitLogger.log(message: "Connected via \(type.rawValue)")

            if !tokenIsValid() {
                getNewToken { [weak self] _ in
                    self?.sendAllPendingData()
                }
            } else {
                sendAllPendingData()
            }

        case .disconnected:
            AppAmbitLogger.log(message: "No network connection")
        }
    }

    
    private func initializeConsumer() {
        AppAmbitLogger.log(message: "Initializing consumer with appKey: \(appKey)")
        
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveSessionEndToDatabaseIfExist()
            _ = SessionManager.initializeStartSession()
            
        }

        getNewToken { _ in
            if Analytics.isManualSessionEnabled {
                AppAmbitLogger.log(message: "Manual session enabled")
                return
            }

            SessionManager.sendSessionEndIfExists()
            SessionManager.startSession() { _ in
                Crashes.shared.loadCrashFileIfExists()
            }
        }
    }
    
    private func getNewToken(completion: @escaping @Sendable (Bool) -> Void) {
        consumerCreationQueue.async {
            if self.isCreatingConsumer {
                AppAmbitLogger.log(message: "Token operation already in progress, queuing callback...")
                self.consumerCreationCallbacks.append(completion)
                return
            }
            
            self.isCreatingConsumer = true
            self.consumerCreationCallbacks.append(completion)
            
            do {
                ConsumerService.shared.updateAppKeyIfNeeded(self.appKey)
                
                if let consumerId = try ServiceContainer.shared.storageService.getConsumerId(), !consumerId.isEmpty {
                    AppAmbitLogger.log(message: "Consumer ID exists (\(consumerId)), renewing token...")
                    
                    ServiceContainer.shared.apiService.getNewToken { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                } else {
                    AppAmbitLogger.log(message: "There is no consumerId, creating a new one...")
                    
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
        DispatchQueue.main.async {
            let success = (errorType == .none)
            AppAmbitLogger.log(message: "Operation completed with: \(errorType)")
            
            self.consumerCreationQueue.async {
                self.isCreatingConsumer = false
                let callbacks = self.consumerCreationCallbacks
                self.consumerCreationCallbacks = []
                
                for callback in callbacks {
                    callback(success)
                }
            }
        }
    }
    
    private func onStart() {
        AppAmbitLogger.log(message: "OnStart")
        self.initializeServices()
        self.initializeConsumer()
    }
    
    private func onResume() {
        AppAmbitLogger.log(message: "onResume: GetNewToken, RemoveSavedEndSessionToFile, SendBatchLogs, SendBatchEvents")
        
        if !tokenIsValid() {
            getNewToken { [weak self] success in
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
        sendAllPendingData();
    }
    
    private func sendAllPendingData() {
        SessionManager.sendBatchSessions { _ in
            Crashes.shared.loadCrashFileIfExists { _ in
                Analytics.sendBatchEvents()
                Crashes.sendBatchLogs()
            }
        }
    }
    
    
    private func onSleep() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSessionToFile()
        }
    }
    
    private func onEnd() {
        if !Analytics.isManualSessionEnabled {
            SessionManager.saveEndSessionToFile()
        }
    }
    
    private func tokenIsValid() -> Bool {
        guard let token = ServiceContainer.shared.apiService.token else {
            return false
        }
        return !token.isEmpty
    }
}
