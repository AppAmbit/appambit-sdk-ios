import Foundation
final class SessionManager: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    private nonisolated(unsafe) static var _sessionId: String?
    nonisolated(unsafe) static var isSessionActive: Bool = false
    
    static let shared = SessionManager()
    private init (){ }

    private static let syncQueue = DispatchQueue(label: "com.appambit.sessionmanager.operations")

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }

    static func startSession() {
        debugPrint("StartSession called");
        syncQueue.async(flags: .barrier) {
            if isSessionActive {
                return;
            }
            
            let dateUtcNow = DateUtils.utcNow
            
            let startSession = StartSessionEndpoint(utcNow: dateUtcNow)
            shared.apiService?.executeRequest(
                startSession,
                    responseType: SessionResponse.self
                ) { response in
                    debugPrint("[SessionManager]: Start Session with Error Type: \(response.errorType.rawValue)")
                                
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
                    }
                }
            
            isSessionActive = true
        }
    }
    
    static func endSession() {
        debugPrint("endSession called");
        syncQueue.sync {
            if !isSessionActive {
                return;
            }
    
            let dateEnd = DateUtils.utcNow
            
            let sessionData = SessionData(
                id: UUID().uuidString,
                sessionId: _sessionId,
                timestamp: dateEnd,
                sessionType: .end
            )
            
            sendEndSessionOrSaveLocally(endSession: sessionData)
        }
    }
    
    private static func sendEndSessionOrSaveLocally(endSession: SessionData) {        
        shared.apiService?.executeRequest(EndSessionEndpoint(endSession: endSession),
                           responseType: EndSessionResponse.self,
                           completion:  {response in
            
            if response.errorType != .none {
                _ = try? shared.storageService?.putSessionData(endSession)
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
}
