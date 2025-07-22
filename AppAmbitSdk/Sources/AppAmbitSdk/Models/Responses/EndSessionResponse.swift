struct EndSessionResponse: Decodable {
    let sessionId: String
    let consumerId: String
    let startedAt: String
    let endAt: String

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case consumerId = "consumer_id"
        case startedAt = "started_at"
        case endAt = "end_at"
    }
}
