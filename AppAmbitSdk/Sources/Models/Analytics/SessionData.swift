import Foundation

struct SessionData: Codable, DictionaryConvertible {
    /// Unique identifier for the session data.
    var id: String?
    
    /// Unique identifier for the end session.
    var sessionId: String?
    
    /// Timestamp of the session data, indicating when the session started or ended.
    var timestamp: Date
    
    /// Session type, indicating whether it is session end or start to identify the timestamps.
    var sessionType: SessionType?
    
    init(
        id: String? = nil,
        sessionId: String? = nil,
        timestamp: Date,
        sessionType: SessionType? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.sessionType = sessionType
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "timestamp": DateUtils.utcIsoFormatString(from: timestamp)
        ]
        
        if let sessionId = sessionId, let intSessionId = Int(sessionId) {
            dict["session_id"] = intSessionId
        }
        
        return dict
    }
}
