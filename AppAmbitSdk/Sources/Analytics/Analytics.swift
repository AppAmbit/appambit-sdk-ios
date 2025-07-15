import Foundation

public final class Analytics {
    
    private nonisolated(unsafe) static var apiService: ApiService?
    private nonisolated(unsafe) static var storageService: StorageService?
    
    private static let syncQueue = DispatchQueue(label: "com.yourapp.analytics.syncQueue")
    
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
}
