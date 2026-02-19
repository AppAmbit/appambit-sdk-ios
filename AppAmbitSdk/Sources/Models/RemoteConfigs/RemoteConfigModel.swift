import Foundation

class RemoteConfigModel: Codable, DictionaryConvertible {
 
    var key: String
    var value: String
    
    enum CodingKeys: String, CodingKey {
        case key = "key"
        case value = "value"
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key)!
        value = try c.decodeIfPresent(String.self, forKey: .value)!
    }

    public init(
        key: String,
        value: String
        
    ) {
        self.key = key
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(key, forKey: .key)
        try c.encodeIfPresent(value, forKey: .value)
    }
    
    // MARK: - DictionaryConvertible
    
    public func toDictionary() -> [String: Any] {
        return [
            "key": key,
            "value": value
        ]
    }
    
}
