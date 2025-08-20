import Foundation

struct SessionsPayload: Codable, DictionaryConvertible {
    let sessions: [SessionBatch]
    
    public func toDictionary() -> [String: Any] {
        return [
            "sessions": sessions.map { $0.toDictionary() }
        ]
    }
}

struct SessionBatch: Codable, DictionaryConvertible {
    let id: String
    let sessionId: String?
    let startedAt: Date?
    let endedAt: Date?
    
    func toDictionary() -> [String: Any] {
        return [
            "started_at": startedAt.map { DateUtils.utcIsoFormatString(from: $0) } ?? NSNull(),
            "ended_at": endedAt.map { DateUtils.utcIsoFormatString(from: $0) } ?? NSNull()
        ]
    }
}
