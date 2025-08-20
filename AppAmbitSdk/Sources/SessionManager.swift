import Foundation

final class SessionManager: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    private var isSendingBatch = false
    private static let batchLock = NSLock()
    private static let batchSendTimeout: TimeInterval = 10
    private var _sessionId: String = ""
    private var _isSessionActive: Bool = false
    
    private static let stateQueue = DispatchQueue(label: "com.appambit.sessionmanager.state", attributes: .concurrent)
    private static let syncQueue = DispatchQueue(label: "com.appambit.sessionmanager.operations")
    private static let syncQueueBatch = DispatchQueue(label: "com.appambit.sessionmanager.batch")
    

    static let shared = SessionManager()
    private init() {}
    
    private var _sessionLocalId: String = ""
    
    internal private(set) static var sessionId: String {
        get { stateQueue.sync { shared._sessionId } }
        set { stateQueue.sync (flags: .barrier) { shared._sessionId = newValue } }
    }

    internal private(set) static var isSessionActive: Bool {
        get { stateQueue.sync { shared._isSessionActive } }
        set { stateQueue.sync(flags: .barrier) { shared._isSessionActive = newValue } }
    }

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }

    static func startSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        AppAmbitLogger.log(message: "StartSession called")

            
        let workItem = DispatchWorkItem {
            let hasServerId = SessionManager.sessionId.isUInt64Number == true
            
            if SessionManager.isSessionActive && hasServerId {
                completion?(AppAmbitLogger.buildError(message: "There is already an active session"))
                return
            }

            let fetched = try? shared.storageService?.getSessionById(shared._sessionLocalId)
            let sessionStart: SessionData = fetched ?? initializeStartSession()

            sendStartSession(dateUtcNow: sessionStart.timestamp) { errorType, data in
                AppAmbitLogger.log(message:"Start Session with Error Type: \(errorType.rawValue)")

                if let sessionIdInt = data?.sessionId {
                    SessionManager.sessionId = String(sessionIdInt)
                }

                if errorType != .none {
                    completion?(AppAmbitLogger.buildError(message: "Start session failed with errorType: \(errorType)"))
                    return
                }
                
                completion?(nil)
                _ = try? shared.storageService?.deleteSessionById(shared._sessionLocalId)
            }
        }

        syncQueue.async(execute: workItem)
    }

    static func initializeStartSession() -> SessionData {
        SessionManager.isSessionActive = true
        let sessionLocalId = UUID().uuidString
        shared._sessionLocalId = sessionLocalId
        SessionManager.sessionId = sessionLocalId
        let data = SessionData(
            id: sessionLocalId,
            sessionId: nil,
            timestamp: DateUtils.utcNow,
            sessionType: .start
        )
        _ = try? shared.storageService?.putSessionData(data)
        return data
    }


    private static func sendStartSession(
        dateUtcNow: Date,
        completion: @escaping @Sendable (ApiErrorType, SessionResponse?) -> Void
    ) {
        let startSession = StartSessionEndpoint(utcNow: dateUtcNow)
        shared.apiService?.executeRequest(
            startSession,
            responseType: SessionResponse.self
        ) { response in
            completion(response.errorType, response.data)
        }
    }

    static func endSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        AppAmbitLogger.log(message: "End Session called")
        let workItem = DispatchWorkItem {
            if !SessionManager.isSessionActive {
                completion?(AppAmbitLogger.buildError(message: "There is no active section to end"))
                return
            }
            
            SessionManager.isSessionActive = false
            SessionManager.sessionId = ""
            shared._sessionLocalId = ""
            
            let dateEnd = DateUtils.utcNow

            let sessionData = SessionData(
                id: UUID().uuidString,
                sessionId: SessionManager.sessionId,
                timestamp: dateEnd,
                sessionType: .end
            )

            sendSessionEndOrSaveLocally(endSession: sessionData, completion: completion)
        }

        syncQueue.async(execute: workItem)
    }

    private static func sendSessionEndAndDeleteLocally(
        endSession: SessionData,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let payload: SessionData = {
            guard let sid = endSession.sessionId, sid.isUInt64Number == true else {
                var m = endSession
                m.sessionId = nil
                return m
            }
            return endSession
        }()

        shared.apiService?.executeRequest(EndSessionEndpoint(endSession: payload), responseType: EndSessionResponse.self) { response in
            if response.errorType != .none {
                AppAmbitLogger.log(message: response.message ?? "")
                completion?(AppAmbitLogger.buildError(message: response.message ?? ""))
                return
            }
            
            completion?(nil)
            _ = try? shared.storageService?.deleteSessionById(endSession.id ?? "")
        }
    }
    
    private static func sendSessionEndOrSaveLocally(
        endSession: SessionData,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let payload: SessionData = {
            guard let sid = endSession.sessionId, sid.isUInt64Number == true else {
                var m = endSession
                m.sessionId = nil
                return m
            }
            return endSession
        }()
        
        _ = try? shared.storageService?.putSessionData(payload)

        shared.apiService?.executeRequest(EndSessionEndpoint(endSession: payload), responseType: EndSessionResponse.self) { response in
            if response.errorType != .none {
                AppAmbitLogger.log(message: response.message ?? "")
                completion?(AppAmbitLogger.buildError(message: response.message ?? ""))
                return
            }
            
            _ = try? shared.storageService?.deleteSessionById(payload.id ?? "")
            completion?(nil)
        }
    }


    static func saveEndSessionToFile() {
        syncQueue.async(flags: .barrier) {
            let sessionData = SessionData(
                id: shared._sessionLocalId.isEmpty ? UUID().uuidString :  shared._sessionLocalId,
                sessionId: (SessionManager.sessionId.isUInt64Number ? SessionManager.sessionId : nil ),
                timestamp: DateUtils.utcNow,
                sessionType: .end
            )
            FileUtils.save(sessionData)
        }
    }

    static func sendSessionEndIfExists() {
        syncQueue.async(flags: .barrier) {
            guard let endSession: SessionData = try? shared.storageService?.getSessionById(shared._sessionLocalId) else {
                return
            }
            
            sendSessionEndAndDeleteLocally(endSession: endSession)
        }
    }
    
    static func saveSessionEndToDatabaseIfExist() {
        guard let endSession: SessionData = FileUtils.getSavedSingleObject(SessionData.self) else {
            return
        }
        
        _ = try? shared.storageService?.putSessionData(endSession)
    }

    static func removeSavedEndSession() {
        syncQueue.async(flags: .barrier) {
            _ = FileUtils.getSavedSingleObject(SessionData.self)
        }
    }

    static func sendBatchSessions() {
        batchLock.lock()
        if shared.isSendingBatch {
            batchLock.unlock()
            AppAmbitLogger.log(message: "SendBatchSessions skipped: alreadt in progress")
            return
        }
        shared.isSendingBatch = true
        batchLock.unlock()

        let finish: @Sendable () -> Void = {
            batchLock.lock()
            let wasSending = shared.isSendingBatch
            shared.isSendingBatch = false
            batchLock.unlock()
            if wasSending {
                AppAmbitLogger.log(message: "SendBatchSessions: released")
            }
        }

        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: batchSendTimeout, repeats: false) { _ in
                batchLock.lock()
                let needsRelease = shared.isSendingBatch
                shared.isSendingBatch = false
                batchLock.unlock()
                if needsRelease {
                    AppAmbitLogger.log(message: "SendBatchSessions timeout: releasing lock")
                }
            }
        }

        getSessionsInDb { sessions, error in
            if let error = error {
                AppAmbitLogger.log(message: "Error getting sessions: \(error.localizedDescription)")
                finish()
                return
            }

            guard let sessions = sessions, !sessions.isEmpty else {
                AppAmbitLogger.log(message: "There are no sessions to send")
                finish()
                return
            }

            let sessionsBatch = SessionsPayload(sessions: sessions)
            let sessionBatchEndpoint = SessionBatchEndpoint(batchSession: sessionsBatch)

            shared.apiService?.executeRequest(sessionBatchEndpoint, responseType: BatchResponse.self) { resultApi in
                defer { finish() }

                if resultApi.errorType != .none {
                    AppAmbitLogger.log(message: "Sessions were not sent: \(resultApi.message ?? "")")
                } else {
                    AppAmbitLogger.log(message: "Sessions sent successfully")
                    do {
                        try shared.storageService?.updateSessionsIdsInEvents(sessions)
                        try shared.storageService?.updateSessionsIdsInLogs(sessions)
                        try shared.storageService?.deleteSessionList(sessions)
                    } catch {
                        AppAmbitLogger.log(message: "Failed to delete sessions from DB: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private static func sendSessionsWithSessionId(
        completion: @escaping @Sendable (_ error: Error?) -> Void
    ) {
        getUnpairedSessions { sessions, error in
            if let error = error {
                AppAmbitLogger.log(message: error.localizedDescription)
                completion(error)
                return
            }

            let sessions = sessions ?? []
            if sessions.isEmpty {
                completion(nil)
                return
            }

            for session in sessions {
                sendSession(session) { err in
                    if let _ = err {
                        AppAmbitLogger.log(message: "error to send Session \(session.id ?? "")")
                    }
                }
            }
        }
    }

    private static func sendSession(
        _ session: SessionData,
        completion: @escaping @Sendable (_ error: Error?) -> Void
    ) {
        if session.sessionType == .end {
            sendEndSession(endSession: session) { errorType, error in
                if errorType != ApiErrorType.none {
                    completion(error)
                    return
                }

                do {
                    try shared.storageService?.deleteSessionById(session.id ?? "")
                    AppAmbitLogger.log(message: "Session \(session.id ?? "") deleted successfully")
                    completion(nil)
                } catch {
                    AppAmbitLogger.log(message: "Failed to delete end session: \(error.localizedDescription)")
                    completion(error)
                }
            }
        } else {
            sendStartSession(dateUtcNow: session.timestamp) { errorType, _ in
                if errorType != ApiErrorType.none {
                    completion(AppAmbitLogger.buildError(message: "Failed to delete Send Start Session"))
                    return
                }

                do {
                    try shared.storageService?.deleteSessionById(session.id ?? "")
                    AppAmbitLogger.log(message: "Session \(session.id ?? "") deleted successfully")
                    completion(nil)
                } catch {
                    AppAmbitLogger.log(message: "Failed to delete start session: \(error.localizedDescription)")
                    completion(error)
                }
            }
        }
    }

    private static func sendEndSession(
        endSession: SessionData,
        completion: @escaping @Sendable (_ errorType: ApiErrorType?, _ error: Error?) -> Void
    ) {
        shared.apiService?.executeRequest(
            EndSessionEndpoint(endSession: endSession),
            responseType: EndSessionResponse.self
        ) { (response: ApiResult<EndSessionResponse>) in
            completion(response.errorType, response.errorType == .none ? nil : AppAmbitLogger.buildError(message: response.message ?? "Unknown error"))
        }
    }

    private static func getUnpairedSessions(
        completion: @escaping @Sendable (_ session: [SessionData]?, _ error: Error?) -> Void
    ) {
        let workItem = DispatchWorkItem {
            do {
                let sessions = try shared.storageService?.getUnpairedSessions()
                completion(sessions, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
        syncQueueBatch.async(execute: workItem)
    }

    private static func getSessionsInDb(
        completion: @escaping @Sendable (_ sessions: [SessionBatch]?, _ error: Error?) -> Void
    ) {
        let workItem = DispatchWorkItem {
            do {
                let sessions = try shared.storageService?.getOldest100Sessions()
                completion(sessions, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
        syncQueueBatch.async(execute: workItem)
    }
}
