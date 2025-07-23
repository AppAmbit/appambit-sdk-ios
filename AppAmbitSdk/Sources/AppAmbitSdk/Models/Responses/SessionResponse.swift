struct SessionResponse: Decodable {
    let sessionId: Int
    
    init(sessionId: Int) {
        self.sessionId = sessionId
    }
    
    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}
