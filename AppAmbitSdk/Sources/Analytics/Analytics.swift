import Foundation

public final class Analytics {
    private nonisolated(unsafe) static var apiService: ApiService?
    private nonisolated(unsafe) static var storageService: StorageService?
    
    private static let isolationQueue = DispatchQueue(
        label: "com.appambit.analytics.isolation",
        qos: .default,
        attributes: []
    )
    
    private init() {}
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        self.apiService = apiService
        self.storageService = storageService
    }
    
    public static func setUserId(_ userId: String) {
        isolationQueue.async {
            do {
                try storageService?.putUserId(userId)
            } catch {
                debugPrint("Error putting userId: \(error)")
            }
        }
    }
    
    public static func setEmail(_ email: String) {
        isolationQueue.async {
            do {
                try storageService?.putUserEmail(email)
            } catch {
                debugPrint("Error putting email: \(error)")
            }
        }
    }
    
    public static func clearToken() {
        isolationQueue.async {
            ServiceContainer.shared.apiService.setToken("")
        }
    }
    
    public static func trackEvent(eventTitle: String, data: [String: String], createdAt: Date?) {
        sendOrSaveEvent(eventTitle: eventTitle, data: data, createdAt: createdAt)
    }
    
    private static func sendOrSaveEvent(eventTitle: String, data: [String: String], createdAt: Date?) {
        let event = Event(
            name: eventTitle,
            metadata: data
        )
        
        let endpoint = EventEndpoint(event: event)
        
        self.apiService?.executeRequest(endpoint, responseType: EventResponse.self) { result in
            if result.errorType != .none {
                debugPrint("Save on datbase event: \(result.message ?? "")")
                return
            }
            
            debugPrint("Log send")
        }
    }
}
