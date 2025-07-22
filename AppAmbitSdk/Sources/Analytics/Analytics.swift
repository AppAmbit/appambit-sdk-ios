import Foundation

public final class Analytics {
    
    private nonisolated(unsafe) static var apiService: ApiService?
    private nonisolated(unsafe) static var storageService: StorageService?
    nonisolated(unsafe) static var isManualSessionEnabled: Bool = false
    
    private static let syncQueue = DispatchQueue(label: "com.appambit.analytics.syncQueue")
    
    private init() {}
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        syncQueue.sync {
            self.apiService = apiService
            self.storageService = storageService
        }
    }

    public static func setUserId(_ userId: String) {
        syncQueue.sync {
            do {
                try storageService?.putUserId(userId)
            } catch {
                debugPrint("Error putting userId: \(error)")
            }
        }
    }
    
    public static func setEmail(_ email: String) {
        syncQueue.sync {
            do {
                try storageService?.putUserEmail(email)
            } catch {
                debugPrint("Error putting email: \(error)")
            }
        }
    }    
    public static func startSession() {
        SessionManager.startSession()
    }

    public static func endSession() {
        SessionManager.endSession()
    }
    
    public static func enableManualSession() {
        syncQueue.sync {
            
            isManualSessionEnabled = true
        }
    }
}
