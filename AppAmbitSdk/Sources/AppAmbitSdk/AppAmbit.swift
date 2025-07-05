import UIKit
import Foundation

public final class AppAmbit: @unchecked Sendable {
    private nonisolated(unsafe) static var instance: AppAmbit?

    private var appKey: String
    private let workerQueue = DispatchQueue(label: "com.appambit.workerQueue")
    private static let instanceQueue = DispatchQueue(label: "com.appambit.instance.queue")

    private init(appKey: String) {
        self.appKey = appKey
        setupLifecycleObservers()
        initializeServices()
        initializeConsumer()
    }

    public static func start(appKey: String) {
        instanceQueue.sync {
            if instance == nil {
                instance = AppAmbit(appKey: appKey)
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

    @objc private func appDidBecomeActive() {
        debugPrint("[AppAmbit] App did become active")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.getNewToken { success in
                if success {
                    self.sendPendingLogs()
                }
            }
        }
    }

    @objc private func appWillResignActive() {
        debugPrint("[AppAmbit] App will resign active")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.saveSessionState()
        }
    }

    @objc private func appDidEnterBackground() {
        debugPrint("[AppAmbit] App did enter background")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.flushDataToDisk()
        }
    }

    @objc private func appWillEnterForeground() {
        debugPrint("[AppAmbit] App will enter foreground")
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            self.prepareForForeground()
        }
    }

    @objc private func appWillTerminate() {
        debugPrint("[AppAmbit] App will terminate")
        workerQueue.sync { [weak self] in
            guard let self = self else { return }
            self.cleanupBeforeTerminate()
        }
    }

    private func initializeServices() {
        let _ = ServiceContainer.shared.apiService
        let _ = ServiceContainer.shared.appInfoService
    }

    private func initializeConsumer() {
        debugPrint("[AppAmbit] Initializing consumer with appKey: \(appKey)")
        getNewToken { [weak self] success in
            if success {
                debugPrint("Created consumer")
            }
        }
    }

    private func getNewToken(completion: @escaping @Sendable (Bool) -> Void) {
        ServiceContainer.shared.apiService.createConsumer(appKey: appKey) { [weak self] errorType in
            DispatchQueue.main.async {
                if errorType == .none {
                    debugPrint("[AppAmbit] Created consumer")
                    completion(true)
                } else {
                    debugPrint("[AppAmbit] Error with: \(errorType)")
                    completion(false)
                }
            }
        }
    }

    private func sendPendingLogs() {
        debugPrint("[AppAmbit] Sending pending logs...")
    }

    private func saveSessionState() {
        debugPrint("[AppAmbit] Saving session state...")
    }

    private func flushDataToDisk() {
        debugPrint("[AppAmbit] Flushing data to disk...")
    }

    private func prepareForForeground() {
        debugPrint("[AppAmbit] Preparing for foreground...")
    }

    private func cleanupBeforeTerminate() {
        debugPrint("[AppAmbit] Cleaning up before app terminate...")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
