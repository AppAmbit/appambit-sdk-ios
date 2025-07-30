import Foundation
final class SessionManager: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    private var isSendingBatch = false

    private nonisolated(unsafe) static var _sessionId: String?
    nonisolated(unsafe) static var isSessionActive: Bool = false
    static let tag = "SessionManager"
    
    static let shared = SessionManager()
    private init (){ }

    private static let syncQueue = DispatchQueue(label: "com.appambit.sessionmanager.operations")
    private static let syncQueueBatch = DispatchQueue(label: "com.appambit.sessionmanager.batch")

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }

    static func startSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        debugPrint("\(tag) StartSession called");
        let workItem = DispatchWorkItem {
            if isSessionActive {
                completion?(AppAmbitLogger.buildError(message: "There is already an active session"))
                return;
            }
            
            let dateUtcNow = DateUtils.utcNow
            
            let startSession = StartSessionEndpoint(utcNow: dateUtcNow)
            shared.apiService?.executeRequest(
                startSession,
                    responseType: SessionResponse.self
                ) { response in
                    debugPrint("[\(tag)]: Start Session with Error Type: \(response.errorType.rawValue)")
                                
                    var sessionId = ""
                    if let sessionIdInt = response.data?.sessionId {
                        sessionId = String(sessionIdInt)
                    }
                                                            
                    if response.errorType != .none {
                        _ = try? shared.storageService?.putSessionData(SessionData(
                            id: UUID().uuidString,
                            sessionId: sessionId,
                            timestamp: dateUtcNow,
                            sessionType: .start
                        ))
                        _sessionId = sessionId
                        AppAmbitLogger.log(message: response.message ?? "", context: tag)
                        completion?(AppAmbitLogger.buildError(message: response.message ?? ""))
                    } else {
                        completion?(nil)
                    }
                }
            
            isSessionActive = true
        }
        
        syncQueue.async(execute: workItem)
    }
    
    static func endSession(completion: (@Sendable (Error?) -> Void)? = nil) {
        debugPrint("[\(tag)]: End Session called");
        let workItem = DispatchWorkItem {
            if !isSessionActive {
                completion?(AppAmbitLogger.buildError(message: "There is no active section to end"))
                return;
            }
    
            let dateEnd = DateUtils.utcNow
            
            let sessionData = SessionData(
                id: UUID().uuidString,
                sessionId: _sessionId,
                timestamp: dateEnd,
                sessionType: .end
            )
            
            sendEndSessionOrSaveLocally(endSession: sessionData, completion: completion)
        }
        
        syncQueue.async(execute: workItem)
    }
    
    private static func sendEndSessionOrSaveLocally(endSession: SessionData, completion: (@Sendable (Error?) -> Void)? = nil) {
        shared.apiService?.executeRequest(EndSessionEndpoint(endSession: endSession),
                           responseType: EndSessionResponse.self,
                           completion:  { response in
            
            if response.errorType != .none {
                AppAmbitLogger.log(message: response.message ?? "", context: tag)
                completion?(AppAmbitLogger.buildError(message: response.message ?? ""))
                _ = try? shared.storageService?.putSessionData(endSession)
            } else {
                completion?(nil)
            }
        })
        
        _sessionId = nil
        isSessionActive = false
    }
    
    static func saveEndSession() {
        syncQueue.async(flags: .barrier) {
            
            let sessionData = SessionData(
                id: UUID().uuidString,
                sessionId: _sessionId,
                timestamp: DateUtils.utcNow,
                sessionType: .end
            )
            
            FileUtils.save(sessionData)
        }
    }
    
    static func sendEndSessionIfExists()  {
        syncQueue.async(flags: .barrier) {
            guard let endSession: SessionData = FileUtils.getSavedSingleObject(SessionData.self) else {
                return
            }
            
            sendEndSessionOrSaveLocally(endSession: endSession)
        }
    }
    
    static func removeSavedEndSession() {
        syncQueue.async(flags: .barrier) {
            _ = FileUtils.getSavedSingleObject(SessionData.self)                        
        }
    }
    
    static func sendBatchSessions() {
        let workItem = DispatchWorkItem {
            guard !shared.isSendingBatch else {
                AppAmbitLogger.log(message: "SendBatchSessions skipped: already in progress", context: tag)
                return
            }
            shared.isSendingBatch = true
            AppAmbitLogger.log(message: "SendBatchSessions started", context: tag)
            
            do {
                getSessionsInDb { sessions, error in
                    if let error = error {
                        AppAmbitLogger.log(message: "Error getting sessions: \(error.localizedDescription)", context: tag)
                        finish()
                        return
                    }

                    guard let sessions = sessions, !sessions.isEmpty else {
                        AppAmbitLogger.log(message: "There are no sessions to send", context: tag)
                        finish()
                        return
                    }

                    let sessionsBatch = SessionsPayload(sessions: sessions)
                    let sessionBatchEndpoint = SessionBatchEndpoint(batchSession: sessionsBatch)

                    shared.apiService?.executeRequest(sessionBatchEndpoint, responseType: BatchResponse.self) { resultApi in
                        if resultApi.errorType != .none {
                            AppAmbitLogger.log(message: "Sessions were not sent: \(resultApi.message ?? "")", context: tag)
                        } else {
                            AppAmbitLogger.log(message: "Sessions sent successfully", context: tag)
                            do {
                                try shared.storageService?.deleteSessionList(sessions)
                            } catch {
                                AppAmbitLogger.log(message: "Failed to delete sessions from DB: \(error.localizedDescription)", context: tag)
                            }
                        }
                        finish()
                    }
                }
            } catch {
                AppAmbitLogger.log(message: "Unexpected error in sendBatchSessions: \(error.localizedDescription)", context: tag)
                finish()
            }

            @Sendable func finish() {
                syncQueueBatch.async {
                    shared.isSendingBatch = false
                }
            }
        }

        syncQueueBatch.async(execute: workItem)
    }

    
    private static func getSessionsInDb(completion: @escaping @Sendable (_ sessions: [SessionBatch]?, _ error: Error?) -> Void) {
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
