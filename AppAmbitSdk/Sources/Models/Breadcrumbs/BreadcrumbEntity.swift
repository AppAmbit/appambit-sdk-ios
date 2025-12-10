import Foundation

class BreadcrumbEntity: Breadcrumb, @unchecked Sendable {
 
    var id: String
    var sessionId: String?
    var createdAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name = "name"
        case sessionId = "session_id"
        case createdAt = "created_at"
    }
    
    public init(
        id: String,
        sessionId: String? = nil,
        name: String,
        createdAt: Date,
    ) {
        self.id = id
        self.sessionId = sessionId
        self.createdAt = createdAt
        super.init(name: name)
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
        try container.encodeIfPresent(sessionId, forKey: .sessionId)
        let dateString = DateUtils.utcCustomFormatString(from: createdAt)
        try container.encode(dateString, forKey: .createdAt)
    }
    
    public override func toDictionary() -> [String: Any] {
        var dict = super.toDictionary()
        
        if let sessionId = sessionId {
            dict["session_id"] = sessionId
        }
        
        dict["created_at"] = DateUtils.utcCustomFormatString(from: createdAt)
        
        return dict
    }
    
}

extension BreadcrumbEntity {
    func withCopy(
        id: String? = nil,
        sessionId: String? = nil,
        name: String? = nil,
        createdAt: Date? = nil,
    ) -> BreadcrumbEntity {
        BreadcrumbEntity(
            id: id ?? self.id,
            sessionId: sessionId ?? self.sessionId,
            name: name ?? self.name,
            createdAt: createdAt ?? self.createdAt,
        )
    }
}

extension BreadcrumbEntity {
    func toData(sessionId: String) -> BreadcrumbData {
        BreadcrumbData(id: id, sessionId: sessionId, name: name, timestamp: createdAt)
    }
}
