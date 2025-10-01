import Foundation

@objcMembers
public final class Analytics: NSObject, @unchecked Sendable {
    public typealias ErrorCompletion = @Sendable (Error?) -> Void

    private var apiService: ApiService?
    private var storageService: StorageService?
    nonisolated(unsafe) static var isManualSessionEnabled: Bool = false

    private var isSendingBatch = false
    private var waiters: [ErrorCompletion] = []
    private var batchTimeoutTimer: DispatchSourceTimer?
    private static let batchSendTimeoutSeconds: Int = 30

    private override init() { super.init() }
    public static let shared = Analytics()

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }

    public static func setUserId(_ userId: String, completion: @escaping ErrorCompletion = { _ in }) {
        Queues.state.async {
            do {
                try shared.storageService?.putUserId(userId)
                completion(nil)
            } catch {
                AppAmbitLogger.log(error: error)
                completion(error)
            }
        }
    }

    public static func setEmail(_ email: String, completion: @escaping ErrorCompletion = { _ in }) {
        Queues.state.async {
            do {
                try shared.storageService?.putUserEmail(email)
                completion(nil)
            } catch {
                AppAmbitLogger.log(message: "Error putting email: \(error)")
                completion(error)
            }
        }
    }

    public static func startSession(completion: @escaping ErrorCompletion = { _ in }) {
        SessionManager.startSession(completion: completion)
    }

    public static func endSession(completion: @escaping ErrorCompletion = { _ in }) {
        SessionManager.endSession(completion: completion)
    }

    public static func enableManualSession() {
        Queues.state.async { isManualSessionEnabled = true }
    }

    public static func clearToken() {
        Queues.state.async { ServiceContainer.shared.apiService.setToken("") }
    }

    public static func trackEvent(
        eventTitle: String,
        data: [String: String],
        createdAt: Date? = nil,
        completion: @escaping ErrorCompletion = { _ in }
    ) {
        sendOrSaveEvent(
            eventTitle: eventTitle,
            data: data,
            createdAt: createdAt,
            completion: completion
        )
    }

    public static func generateTestEvent(completion: @escaping ErrorCompletion = { _ in }) {
        Queues.state.async {
            sendOrSaveEvent(
                eventTitle: "Test Event",
                data: ["Event": "Custom Event"],
                createdAt: nil,
                completion: completion
            )
        }
    }

    public static func sendBatchEvents(completion: @escaping ErrorCompletion = { _ in }) {
        let finish: ErrorCompletion = { err in
            Queues.batch.async {
                shared.isSendingBatch = false
                shared.batchTimeoutTimer?.cancel()
                shared.batchTimeoutTimer = nil
                let cbs = shared.waiters
                shared.waiters.removeAll()
                for cb in cbs { DispatchQueue.global(qos: .utility).async { cb(err) } }
            }
        }

        Queues.batch.async {
            shared.waiters.append(completion)
            guard !shared.isSendingBatch else {
                AppAmbitLogger.log(message: "SendBatchEvents skipped: already in progress")
                return
            }
            shared.isSendingBatch = true

            let t = DispatchSource.makeTimerSource(queue: Queues.batch)
            t.schedule(deadline: .now() + .seconds(batchSendTimeoutSeconds))
            t.setEventHandler {
                AppAmbitLogger.log(message: "SendBatchEvents timeout: releasing gate")
                finish(AppAmbitLogger.buildError(message: "SendBatchEvents timeout"))
            }
            shared.batchTimeoutTimer = t
            t.resume()

            getEventsInDbAsync { events, error in
                Queues.batch.async {
                    if let error = error {
                        AppAmbitLogger.log(message: "Error getting events: \(error.localizedDescription)")
                        finish(error); return
                    }
                    guard let events = events, !events.isEmpty else {
                        AppAmbitLogger.log(message: "There are no events to send")
                        finish(nil); return
                    }

                    let endpoint = EventBatchEndpoint(eventBatch: events)
                    shared.apiService?.executeRequest(endpoint, responseType: BatchResponse.self) { response in
                        Queues.batch.async {
                            if response.errorType != .none {
                                AppAmbitLogger.log(message: "Events were not sent: \(response.message ?? "")")
                                finish(AppAmbitLogger.buildError(message: response.message ?? "Unknown error"))
                                return
                            }
                            do {
                                try shared.storageService?.deleteEventList(events)
                                AppAmbitLogger.log(message: "SendBatchEvents successfully sent")
                                finish(nil)
                            } catch {
                                AppAmbitLogger.log(message: "Failed deleting events: \(error.localizedDescription)")
                                finish(error)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func getEventsInDbAsync(
        _ completion: @escaping @Sendable (_ events: [EventEntity]?, _ error: Error?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
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
        completion: @escaping ErrorCompletion = { _ in }
    ) {
        if !SessionManager.isSessionActive {
            let message = "There is no active session"
            AppAmbitLogger.log(message: message)
            completion(AppAmbitLogger.buildError(message: message, code: 200))
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

        let event = Event(name: eventTitleTruncate, metadata: truncatedData)
        let endpoint = EventEndpoint(event: event)

        shared.apiService?.executeRequest(endpoint, responseType: EventResponse.self) { (resultEvent: ApiResult<EventResponse>) in
            if resultEvent.errorType != .none {
                AppAmbitLogger.log(message: resultEvent.message ?? "Unknown")
                let entity = EventEntity(
                    id: UUID().uuidString,
                    sessionId: SessionManager.sessionId,
                    createdAt: createdAt ?? DateUtils.utcNow,
                    name: eventTitleTruncate,
                    metadata: truncatedData
                )
                storeLogInDb(eventEntity: entity) { _ in
                    DispatchQueue.main.async {
                        completion(AppAmbitLogger.buildError(message: resultEvent.message ?? "", code: 100))
                    }
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    private static func truncate(value: String, maxLength: Int) -> String {
        guard !value.isEmpty else { return value }
        return String(value.prefix(maxLength))
    }

    private static func storeLogInDb(eventEntity: EventEntity, completion: @escaping ErrorCompletion = { _ in }) {
        Queues.state.async {
            do {
                try shared.storageService?.putLogAnalyticsEvent(eventEntity)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
}
