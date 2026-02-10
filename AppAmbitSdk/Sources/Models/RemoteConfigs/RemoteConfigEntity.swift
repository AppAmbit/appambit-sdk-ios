import Foundation

class RemoteConfigEntity: RemoteConfigModel, @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The unique identifier for the remote configuration entity.
    public let id: String
    
    private enum CodingKeys: String, CodingKey {
        case id
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        key: String,
        value: String
    ) {
        self.id = id
        super.init(key: key, value: value)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        
        try super.init(from: decoder)
    }
    
    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
    }
    
    // MARK: - DictionaryConvertible
    
    public override func toDictionary() -> [String: Any] {
        var dict = super.toDictionary()
        dict["id"] = id
        return dict
    }
}
