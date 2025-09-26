struct EndSessionResponse: Decodable {
    let sessionId: Int?
    let startedAt: String?
    let endedAt: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}
