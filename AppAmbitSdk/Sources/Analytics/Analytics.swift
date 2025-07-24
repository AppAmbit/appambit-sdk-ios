import Foundation

public final class Analytics: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    static let TAG = "Analytics"
    nonisolated(unsafe) static var isManualSessionEnabled: Bool = false

    static let shared = Analytics()
    private init() {}

    private static let isolationQueue = DispatchQueue(
        label: "com.appambit.analytics.isolation",
        qos: .default,
        attributes: []
    )

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }
    
    public static func setUserId(_ userId: String, completion: ((Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            do {
                try shared.storageService?.putUserId(userId)
                completion?(nil)
            } catch {
                AppAmbitLogger.log(error: error, context: "Analytics.setUserId")
                completion?(error)
            }
        }

        isolationQueue.async(execute: workItem)
    }
    
    public static func setEmail(_ email: String, completion: ((Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            do {
                try shared.storageService?.putUserEmail(email)
            } catch {
                debugPrint("Error putting email: \(error)")
            }
        }
        
        isolationQueue.async(execute: workItem)
    }
    
    public static func startSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        SessionManager.startSession(completion: completion)
    }

    public static func endSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        SessionManager.endSession(completion: completion)
    }

    public static func enableManualSession() {
        let workItem = DispatchWorkItem {
            isManualSessionEnabled = true
        }
        
        isolationQueue.async(execute: workItem)
    }
    
    public static func clearToken() {
           isolationQueue.async {
               ServiceContainer.shared.apiService.setToken("")
           }
       }
    
    public static func trackEvent(
           eventTitle: String,
           data: [String: String],
           createdAt: Date? = nil,
           completion: (@Sendable (Error?) -> Void)? = nil
       ) {
           sendOrSaveEvent(
               eventTitle: eventTitle,
               data: data,
               createdAt: createdAt,
               completion: completion
           )
       }
       
       private static func sendOrSaveEvent(
               eventTitle: String,
               data: [String: String],
               createdAt: Date?,
               completion: (@Sendable (Error?) -> Void)? = nil
           ) {
               let event = Event(
                   name: eventTitle,
                   metadata: data
               )
               
               let endpoint = EventEndpoint(event: event)
               
               shared.apiService?.executeRequest(endpoint, responseType: EventResponse.self) { (resultEvent: ApiResult<EventResponse>) in
                   if resultEvent.errorType != .none {
                       AppAmbitLogger.log(message: resultEvent.message ?? "Unknown")
                       completion?(AppAmbitLogger.buildError(message: resultEvent.message ?? "", code: 100))
                   } else {
                       completion?(nil)
                   }
               }
       }
}
