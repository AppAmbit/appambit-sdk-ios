import Foundation

class Event: Codable, DictionaryConvertible {
    // MARK: - Properties
    
    /// The name of the event.
    /// - Remark: This is a required field and should be descriptive.
    public var name: String
    
    private var _dataJson: String = "{}"
    
    /// Additional metadata associated with the event.
    /// - Note: Stored as key-value pairs where both keys and values are strings.
    public var metadata: [String: String] {
        get {
            if let data = _dataJson.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return dict
            }
            return [:]
        }
        set {
            if let jsonData = try? JSONSerialization.data(withJSONObject: newValue, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                _dataJson = jsonString
            } else {
                _dataJson = "{}"
            }
        }
    }
    
    /// Computed property that provides JSON string representation of metadata.
    public var dataJson: String {
        get { _dataJson }
        set {
            _dataJson = newValue
            // Update metadata dictionary when dataJson is set
            _ = metadata
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case metadata
    }

    public init(
        name: String,
        metadata: [String: String] = [:]
    ) {
        self.name = name
        self.metadata = metadata
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(metadata, forKey: .metadata)
    }
    
    // MARK: - DictionaryConvertible
    
    public func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "metadata": metadata
        ]    
    }
}
