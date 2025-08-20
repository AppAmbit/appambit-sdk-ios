import Foundation

class EventEntity: Event, @unchecked Sendable {
    // MARK: - Properties
    
    /// A unique identifier for the event.
    public let id: String
    
    /// The date when the event was created.
    /// - Important: Uses UTC format for serialization.
    public let createdAt: Date
    
    public let sessionId: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case createdAt = "created_at"
    }

    public init(
        id: String,
        sessionId: String,
        createdAt: Date,
        name: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sessionId = sessionId
        super.init(name: name, metadata: metadata)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        let dateString = try container.decode(String.self, forKey: .createdAt)
        guard let parsedDate = DateUtils.utcCustomFormatDate(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt,
                in: container,
                debugDescription: "Invalid date format: \(dateString)")
        }
        
        let sessionIdParsed = try container.decode(String.self, forKey: .sessionId)
        
        createdAt = parsedDate
        sessionId = sessionIdParsed
        
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sessionId, forKey: .sessionId)
        let dateString = DateUtils.utcCustomFormatString(from: createdAt)
        try container.encode(dateString, forKey: .createdAt)
    }
}
