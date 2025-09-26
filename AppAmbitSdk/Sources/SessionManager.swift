import Foundation

final class SessionManager: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?

    private var isSendingBatch = false
    private static let batchLock = NSLock()
    private static let batchSendTimeout: TimeInterval = 10
    private var waiters: [(@Sendable (Error?) -> Void)] = []
    private var _endIsSending = false
    private var _endCompletions: [(@Sendable (Error?) -> Void)] = []

    private enum SendBatchError: Error { case timeout }

    private static let stateLock = NSLock()
    private var _sessionId: String = ""
    private var _isSessionActive: Bool = false

    internal private(set) static var sessionId: String {
        get { stateLock.lock(); defer { stateLock.unlock() }; return shared._sessionId }
        set { stateLock.lock(); shared._sessionId = newValue; stateLock.unlock() }
    }

    internal private(set) static var isSessionActive: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return shared._isSessionActive }
        set { stateLock.lock(); shared._isSessionActive = newValue; stateLock.unlock() }
    }

    static let shared = SessionManager()
    private init() {}

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }

    static func startSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        AppAmbitLogger.log(message: "StartSession called")
        Queues.state.async {
            if SessionManager.isSessionActive {
                completion?(AppAmbitLogger.buildError(message: "There is already an active session"))
                return
            }
            
            SessionManager.isSessionActive = true
            let sessionLocalId = UUID().uuidString
            SessionManager.sessionId = sessionLocalId
            let sessionStart = SessionData(
                id: sessionLocalId,
                sessionId: sessionLocalId,
                timestamp: DateUtils.utcNow,
                sessionType: .start
            )
            
            sendSession(sessionStart) { error in
                if let error = error {
                    AppAmbitLogger.log(message: "Error to send Session Start: \(error.localizedDescription)")
                    completion?(error)
                    return
                }
                
                completion?(nil)
                AppAmbitLogger.log(message: "Session Start was sent")
            }
        }
    }
    
    static func endSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        AppAmbitLogger.log(message: "End Session called")
        Queues.state.async {
            if !SessionManager.isSessionActive {
                completion?(AppAmbitLogger.buildError(message: "There is no active session to end"))
                return
            }

            SessionManager.isSessionActive = false
            
            let sessionEnd = SessionData(
                id: UUID().uuidString,
                sessionId: SessionManager.sessionId.isUIntNumber ? SessionManager.sessionId : "",
                timestamp: DateUtils.utcNow,
                sessionType: .end
            )
            
            SessionManager.sessionId = ""
            
            sendSession(sessionEnd) { error in
                if let error = error {
                    AppAmbitLogger.log(message: "Error to send Session Start: \(error.localizedDescription)")
                    completion?(error)
                    return
                }
                
                completion?(nil)
                AppAmbitLogger.log(message: "Session Start was sent")
            }
        }
    }

    static func sendEndSessionFromDatabase(completion: (@Sendable (Error?) -> Void)? = nil) {
        Queues.state.async {
            if let completion = completion { shared._endCompletions.append(completion) }
            guard shared._endIsSending == false else { return }
            shared._endIsSending = true

            guard let storage = shared.storageService else {
                finishEnd(nil); return
            }

            // 1) Leer en BD
            Queues.db.async {
                do {
                    guard let end = try storage.getUnpairedSessionEnd() else {
                        finishEnd(nil); return
                    }

                    // 2) Enviar por red (o usa tu cola 'batch')
                    Queues.batch.async {
                        sendEndSession(endSession: end) { errorType, _ in
                            guard errorType == .none else {
                                finishEnd(AppAmbitLogger.buildError(
                                    message: "Failed to Send End Session: \(errorType.localizedDescription)"
                                ))
                                return
                            }

                            // 3) Borrar en BD
                            Queues.db.async {
                                do {
                                    if let id = end.id, !id.isEmpty {
                                        try shared.storageService?.deleteSessionById(id)
                                    }
                                    finishEnd(nil)
                                } catch {
                                    finishEnd(error)
                                }
                            }
                        }
                    }
                } catch {
                    finishEnd(error)
                }
            }
        }
    }

    
    private static func finishEnd(_ error: Error?) {
        Queues.state.async {
            shared._endIsSending = false
            let handlers = shared._endCompletions
            shared._endCompletions.removeAll()
            DispatchQueue.main.async { handlers.forEach { $0(error) } }
        }
    }

    static func saveEndSession() {
        Queues.state.async {
            let sessionEnd = SessionData(
                id: UUID().uuidString,
                sessionId: (SessionManager.sessionId.isUIntNumber ? SessionManager.sessionId : nil),
                timestamp: DateUtils.utcNow,
                sessionType: .end
            )
            
            Queues.netDecode.async {
                FileUtils.save(sessionEnd)
            }
        }
    }

    static func sendStartSessionIfExist(completion: (@Sendable (Error?) -> Void)? = nil) {
        do {
            guard let _ = shared.storageService else {
                completion?(nil)
                return
            }
            
            guard let startSession = try shared.storageService?.getUnpairedSessionStart() else {
                completion?(nil)
                return
            }

            let startId   = (startSession.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let startedAt = startSession.timestamp

            sendStartSession(dateUtcNow: startedAt) { [startId, startedAt] errorType, response in
                if errorType != .none {
                    completion?(AppAmbitLogger.buildError(
                        message: "Failed to Send Start Session: \(errorType.localizedDescription)"
                    ))
                    return
                }

                guard let sessionIdInt = response?.sessionId else {
                    completion?(AppAmbitLogger.buildError(message: "Missing sessionId in response"))
                    return
                }

                let newSessionId = String(sessionIdInt)
                SessionManager.sessionId = newSessionId

                let payload: [SessionBatch] = [
                    .init(id: startId, sessionId: newSessionId, startedAt: startedAt, endedAt: nil)
                ]

                do {
                    try shared.storageService?.updateLogsAndEventsSessionIds(payload)
                    try shared.storageService?.deleteSessionList(payload)
                    completion?(nil)
                } catch {
                    completion?(error)
                }
            }
        } catch {
            AppAmbitLogger.log(message: error.localizedDescription)
            completion?(error)
        }
    }

    static func saveSessionEndToDatabaseIfExist() {
        do {
            guard let store = shared.storageService else { return }

            let endSession: SessionData? = FileUtils.getSavedSingleObject(SessionData.self)

            guard let end = endSession else { return }

            try store.putSessionData(end)
            FileUtils.deleteSingleObject(SessionData.self)
        } catch {
            AppAmbitLogger.log(message: "saveSessionEndToDatabaseIfExist failed: \(error)")
        }
    }

    
    static func sendEndSessionFromFile(completion: (@Sendable (Error?) -> Void)? = nil) {
        guard let endSession: SessionData = FileUtils.getSavedSingleObject(SessionData.self) else {
            completion?(nil)
            return
        }

        sendEndSession(endSession: endSession) { errorType, _ in
            if errorType != .none {
                completion?(AppAmbitLogger.buildError(
                    message: "Failed to Send End Session: \(errorType.localizedDescription)"
                ))
                return
            }

            FileUtils.deleteSingleObject(SessionData.self)
            completion?(nil)
        }
    }

    static func removeSavedEndSession() {
        Queues.netDecode.async {
            FileUtils.deleteSingleObject(SessionData.self)
        }
    }

    static func sendBatchSessions(completion: (@Sendable (Error?) -> Void)? = nil) {
        batchLock.lock()
        if let completion { shared.waiters.append(completion) }
        if shared.isSendingBatch {
            batchLock.unlock()
            return
        }
        shared.isSendingBatch = true
        batchLock.unlock()

        let finish: @Sendable (_ err: Error?) -> Void = { err in
            batchLock.lock()
            shared.isSendingBatch = false
            let callbacks = shared.waiters
            shared.waiters.removeAll()
            batchLock.unlock()

            for cb in callbacks { DispatchQueue.global().async { cb(err) } }
        }

        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: batchSendTimeout, repeats: false) { _ in
                batchLock.lock()
                let stillSending = shared.isSendingBatch
                batchLock.unlock()
                if stillSending {
                    finish(SendBatchError.timeout)
                }
            }
        }

            getSessionsInDb { sessions, error in
                if let error = error {
                    AppAmbitLogger.log(message: "Error getting sessions: \(error.localizedDescription)")
                    finish(error)
                    return
                }
                
                guard let sessions = sessions, !sessions.isEmpty else {
                    AppAmbitLogger.log(message: "There are no sessions to send")
                    finish(nil)
                    return
                }
                
                let sessionsBatch = SessionsPayload(sessions: sessions)
                let sessionBatchEndpoint = SessionBatchEndpoint(batchSession: sessionsBatch)
                
                shared.apiService?.executeRequest(sessionBatchEndpoint, responseType: [SessionBatch].self) { resultApi in
                    guard resultApi.errorType == .none else {
                        AppAmbitLogger.log(message: "Sessions were not sent: \(resultApi.message ?? "")")
                        finish(NSError(domain: "SendBatchSessions", code: 1, userInfo: [NSLocalizedDescriptionKey: resultApi.message ?? "Unknown error"]))
                        return
                    }
                    
                    guard let serverSessions = resultApi.data, !serverSessions.isEmpty else {
                        AppAmbitLogger.log(message: "Empty sessions response")
                        finish(nil)
                        return
                    }
                    
                    var localIndex: [String: String] = [:]
                    for local in sessions {
                        if let fp = local.fingerPrint, !fp.isEmpty {
                            localIndex[fp] = local.id
                        } else if let sa = local.startedAt, let ea = local.endedAt {
                            let a = DateUtils.utcIsoFormatString(from: sa)
                            let b = DateUtils.utcIsoFormatString(from: ea)
                            localIndex["\(a)-\(b)"] = local.id
                        }
                    }
                    
                    let resolved: [SessionBatch] = serverSessions.compactMap { remote in
                        guard
                            let sa  = remote.startedAt,
                            let ea  = remote.endedAt,
                            let sid = remote.sessionId, !sid.isEmpty
                        else { return nil }
                        
                        let key: String
                        if let fp = remote.fingerPrint, !fp.isEmpty {
                            key = fp
                        } else {
                            let a = DateUtils.utcIsoFormatString(from: sa)
                            let b = DateUtils.utcIsoFormatString(from: ea)
                            key = "\(a)-\(b)"
                        }
                        
                        guard let idLocal = localIndex[key] else { return nil }
                        
                        return SessionBatch(
                            id: idLocal,
                            sessionId: sid,
                            startedAt: sa,
                            endedAt: ea
                        )
                    }
                    
                    let unresolvedCount = sessions.count - resolved.count
                    if unresolvedCount > 0 {
                        AppAmbitLogger.log(message: "Sessions sent, matched: \(resolved.count), unmatched: \(unresolvedCount)")
                    } else {
                        AppAmbitLogger.log(message: "Sessions sent successfully (all matched)")
                    }
                    
                    do {
                        if !resolved.isEmpty {
                            try shared.storageService?.updateLogsAndEventsSessionIds(resolved)
                        }
                        try shared.storageService?.deleteSessionList(sessions)
                        finish(nil)
                    } catch {
                        AppAmbitLogger.log(message: "Failed to persist sessions: \(error.localizedDescription)")
                        finish(error)
                    }
                }
            }
    }

    private static func sendSession( _ session: SessionData, completion: @escaping @Sendable (_ error: Error?) -> Void) {
        if session.sessionType == .start {
            sendStartSession(dateUtcNow: session.timestamp) { errorType, response in
                if errorType != .none {
                    
                    let payload = session.withCopy(sessionId: (session.sessionId?.isUIntNumber ?? false) ? session.sessionId : "")
                    
                    try? shared.storageService?.putSessionData(payload)
                    completion(AppAmbitLogger.buildError(message: "Failed to delete Send Start Session: \(errorType.localizedDescription)"))
                    return
                }
                
                if let sessionIdInt = response?.sessionId {
                    SessionManager.sessionId = String(sessionIdInt)
                }
            }
        } else {
            sendEndSession(endSession: session) { errorType, response in
                if errorType != ApiErrorType.none {
                    SessionManager.sessionId = (session.sessionId?.isUIntNumber ?? false) ? (session.sessionId ?? "") : ""
                    try? shared.storageService?.putSessionData(session)
                    completion(AppAmbitLogger.buildError(message: "Failed to delete Send Start Session: \(errorType.localizedDescription)"))
                    return
                }
            }
        }
}

    private static func sendStartSession( dateUtcNow: Date, completion: @escaping @Sendable (ApiErrorType, SessionResponse?) -> Void ) {
        shared.apiService?.executeRequest(StartSessionEndpoint(utcNow: dateUtcNow), responseType: SessionResponse.self) { response in
            completion(response.errorType, response.data)
        }
    }

    private static func sendEndSession( endSession: SessionData, completion: @escaping @Sendable (ApiErrorType, EndSessionResponse?) -> Void ) {
        shared.apiService?.executeRequest(EndSessionEndpoint(endSession: endSession), responseType: EndSessionResponse.self) { response in
            completion(response.errorType, response.data)
        }
    }

    private static func getSessionsInDb( completion: @escaping @Sendable (_ sessions: [SessionBatch]?, _ error: Error?) -> Void) {
        Queues.batch.async {
            do {
                let sessions = try shared.storageService?.getOldest100Sessions()
                completion(sessions, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
    }
}
