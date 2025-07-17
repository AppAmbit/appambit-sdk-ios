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
    
    private init(appKey: String) {
        debugPrint("[AppAmbit] - INIT")
        self.appKey = appKey
        setupLifecycleObservers()
        onStart()
    }

    public static func start(appKey: String) {
        instanceQueue.async {
            if _instance == nil {
                _instance = AppAmbit(appKey: appKey)
                debugPrint("[AppAmbit] SDK started with appKey: \(appKey)")
            } else {
                debugPrint("[AppAmbit] SDK already started")
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
        debugPrint("[AppAmbit] Deinit called - Observers removed")
    }

    @objc private func appDidBecomeActive() {
        debugPrint("[AppAmbit] appDidBecomeActive")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onResume()
        }
    }
    
    @objc private func appWillResignActive() {
        debugPrint("[AppAmbit] appWillResignActive")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }

    @objc private func appDidEnterBackground() {
        debugPrint("[AppAmbit] appDidEnterBackground")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.onSleep()
        }
    }

    @objc private func appWillEnterForeground() {
        debugPrint("[AppAmbit] appWillEnterForeground")
        workerQueue.async { [weak self] in
            debugPrint("[AppAmbit] onResume: GetNewToken, RemoveSavedEndSession, SendBatchLogs, SendBatchEvents")
            
            guard let self = self else { return }

            if tokenIsValid() {
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
        debugPrint("[AppAmbit] appWillTerminate")
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
        
        reachabilityService.onConnectionChange = handleConnectionChange
        try? reachabilityService.initialize()
    }
    
    @Sendable
    func handleConnectionChange(status: ReachabilityService.ConnectionStatus) {
        switch status {
        case .connected:
            print("Access to a red light")
        case .disconnected:
            print("There is no access to a red light")
        }
    }

    private func initializeConsumer() {
        debugPrint("[AppAmbit] Initializing consumer with appKey: \(appKey)")
        getNewToken { success in
            if success {
                debugPrint("[AppAmbit] Consumer created")
            }
        }
    }

    private func getNewToken(completion: @escaping @Sendable (Bool) -> Void) {
        consumerCreationQueue.async {
            if self.isCreatingConsumer {
                debugPrint("Token operation already in progress, queuing callback...")
                self.consumerCreationCallbacks.append(completion)
                return
            }
            
            self.isCreatingConsumer = true
            self.consumerCreationCallbacks.append(completion)
            
            do {
                _ = ConsumerService.shared.buildRegisterEndpoint(appKey: self.appKey)

                if let consumerId = try ServiceContainer.shared.storageService.getConsumerId(), !consumerId.isEmpty {
                    debugPrint("Consumer ID exists (\(consumerId)), renewing token...")
                    
                    ServiceContainer.shared.apiService.getNewToken { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                } else {
                    debugPrint("There is no consumerId, creating a new one...")
                    
                    ConsumerService.shared.createConsumer(appKey: self.appKey) { errorType in
                        self.handleTokenResult(errorType: errorType)
                    }
                }
            } catch {
                debugPrint("Error reading consumerId: \(error)")
                self.handleTokenResult(errorType: .unknown)
            }
        }
    }

    private func handleTokenResult(errorType: ApiErrorType) {
        DispatchQueue.main.async {
            let success = (errorType == .none)
            debugPrint("[AppAmbit] Operación completada con: \(errorType)")
            
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
        debugPrint("[AppAmbit] OnStart")
        self.initializeServices()
        self.initializeConsumer()
    }
    
    private func onResume() {
        debugPrint("[AppAmbit] onResume: GetNewToken, RemoveSavedEndSession, SendBatchLogs, SendBatchEvents")

        if tokenIsValid() {
            getNewToken { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.sendAllPendingData()
                }
            }
        } else {
            sendAllPendingData();
        }
    }

    private func sendAllPendingData() {
        self.sendPendingLogs()
        self.sendPendingEvents()
        self.sendPendingSessiones()
    }
    
    
    private func onSleep() {
        debugPrint("[AppAmbit] OnSleep: saveEndSession")
    }
    
    private func onEnd() {
        debugPrint("[AppAmbit] onEnd: saveEndSession")
    }
    
    private func sendPendingLogs() {
        debugPrint("[AppAmbit] Sending pending logs...")
    }
    
    private func sendPendingEvents() {
        debugPrint("[AppAmbit] Sending pending events...")
    }
    
    private func sendPendingSessiones() {
        debugPrint("[AppAmbit] Sending pending sessions...")
    }
    
    private func tokenIsValid() -> Bool {
        return ServiceContainer.shared.apiService.token?.isEmpty ?? true
    }
}
