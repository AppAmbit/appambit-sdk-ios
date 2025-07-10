import Foundation

struct SessionData: Codable, Identifiable {
    /// Unique identifier for the session data.
    var id: String = ""

    /// Unique identifier for the end session.
    var sessionId: String?

    /// Timestamp of the session data, indicating when the session started or ended.
    var timestamp: Date

    /// Session type, indicating whether it is session end or start to identify the timestamps.
    var sessionType: SessionType

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case timestamp
        case sessionType = "session_type"
    }
}
