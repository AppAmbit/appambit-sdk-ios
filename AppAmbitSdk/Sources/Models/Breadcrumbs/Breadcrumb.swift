import Foundation

class Breadcrumb: Codable, DictionaryConvertible {
 
    var name: String
    
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)!
    }

    public init(
        name: String,
    ) {
        self.name = name
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
    }
    
    // MARK: - DictionaryConvertible
    
    public func toDictionary() -> [String: Any] {
        return [
            "name": name
        ]
    }
    
}
