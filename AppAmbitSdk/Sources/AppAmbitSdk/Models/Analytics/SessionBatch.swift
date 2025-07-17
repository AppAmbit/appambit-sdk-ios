import Foundation

struct SessionsPayload: Codable {
    let sessions: [SessionBatch]
}

struct SessionBatch: Codable {
    let id: String
    let startedAt: Date?
    let endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}
