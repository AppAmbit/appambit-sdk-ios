import Foundation

public final class Analytics: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    nonisolated(unsafe) static var isManualSessionEnabled: Bool = false
    
    private static let syncQueueBatch = DispatchQueue(label: "com.appambit.crashes.batch", attributes: .concurrent)
    private var isSendingBatch = false

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
                AppAmbitLogger.log(error: error)
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
                AppAmbitLogger.log(message: "Error putting email: \(error)")
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
    
    public static func generateTestEvent(completion: (@Sendable (Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            sendOrSaveEvent(
                eventTitle: "Test Event",
                data: ["Event": "Custom Event"],
                createdAt: nil,
                completion: completion)
        }
        
        isolationQueue.async(execute: workItem)
    }
    
    static func sendBatchEvents() {
          let canSend = syncQueueBatch.sync {
              if shared.isSendingBatch {
                  return false
              } else {
                  shared.isSendingBatch = true
                  return true
              }
          }
          
          guard canSend else {
              AppAmbitLogger.log(message: "SendBatchEvents skipped: already in progress")
              return
          }
          
        let workItem = DispatchWorkItem {
            AppAmbitLogger.log(message: "SendBatchEvents")
                               
            getEventsIndb {events, error in
                if let error = error {
                    AppAmbitLogger.log(message: "Error getting events: \(error.localizedDescription)")
                    finish()
                    return
                }
                
                guard let events = events, !events.isEmpty else {
                    AppAmbitLogger.log(message: "There are no events to send")
                    finish()
                    return
                }
                
                let eventBatch = EventBatchEndpoint(eventBatch: events)
                
                shared.apiService?.executeRequest(eventBatch, responseType: BatchResponse.self) { response in
                    
                    if response.errorType != .none {
                        AppAmbitLogger.log(message: "Events were no sent: \(response.message ?? "")")
                        finish()
                        return
                    }
                    
                    AppAmbitLogger.log(message: "Events sent successfully")
                    do {
                        try shared.storageService?.deleteEventList(events)
                    } catch {
                        AppAmbitLogger.log(message: error.localizedDescription)
                    }
                    
                    finish()
                }
            }
         
           @Sendable func finish() {
               syncQueueBatch.async {
                   shared.isSendingBatch = false
               }
           }
        }
          
          syncQueueBatch.async(execute: workItem)
      }
    
    
    private static func getEventsIndb(completion: @escaping @Sendable (_ logs: [EventEntity]?, _ error: Error?) -> Void) {
        syncQueueBatch.async {
            do {
                let events = try shared.storageService?.getOldest100Events()
                completion(events, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
    }
    
    private static func sendOrSaveEvent(
        eventTitle: String,
        data: [String: String],
        createdAt: Date?,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        if !SessionManager.isSessionActive {
            let message = "There is no active session"
            AppAmbitLogger.log(message: message)
            completion?(AppAmbitLogger.buildError(message: message, code: 200));
            return
        }
        
        let truncatedData = Dictionary(
            data
                .map { key, value in
                    (
                        truncate(value: key, maxLength: AppConstants.trackEventPropertyMaxCharacters),
                        truncate(value: value, maxLength: AppConstants.trackEventPropertyMaxCharacters)
                    )
                }
                .prefix(AppConstants.trackEventMaxPropertyLimit),
            uniquingKeysWith: { first, _ in first }
        )

        let eventTitleTruncate = truncate(value: eventTitle, maxLength: AppConstants.trackEventNameMaxLimit)

        let event = Event(
            name: eventTitleTruncate,
            metadata: truncatedData
        )

        let endpoint = EventEndpoint(event: event)

        shared.apiService?.executeRequest(endpoint, responseType: EventResponse.self) { (resultEvent: ApiResult<EventResponse>) in
            if resultEvent.errorType != .none {
                AppAmbitLogger.log(message: resultEvent.message ?? "Unknown")

                let entity = EventEntity(
                    id: UUID().uuidString,
                    createdAt: DateUtils.utcNow,
                    name: eventTitleTruncate,
                    metadata: truncatedData
                )

                storeLogInDb(eventEntity: entity) { error in
                    DispatchQueue.main.async {
                        completion?(AppAmbitLogger.buildError(message: resultEvent.message ?? "", code: 100))
                    }
                }

            } else {
                DispatchQueue.main.async {
                    completion?(nil)
                }
            }
        }
    }

    private static func truncate(value: String, maxLength: Int) -> String {
        guard !value.isEmpty else { return value }
        return String(value.prefix(maxLength))
    }
    
    private static func storeLogInDb(eventEntity: EventEntity, completion: (@Sendable (Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            do {
                try shared.storageService?.putLogAnalyticsEvent(eventEntity)
                DispatchQueue.main.async {
                    completion?(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
        isolationQueue.async(execute: workItem)
    }
}
