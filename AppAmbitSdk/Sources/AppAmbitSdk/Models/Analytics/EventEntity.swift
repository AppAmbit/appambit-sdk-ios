
import Foundation

public struct EventEntity: Codable {
    // MARK: - Properties
    
    /// A unique identifier for the event.
    public let id: UUID
    
    /// The date when the event was created.
    /// - Important: Uses UTC format for serialization.
    public let createdAt: Date
    
    /// The name of the event.
    /// - Remark: This is a required field and should be descriptive.
    public var name: String
    
    /// Additional metadata associated with the event.
    /// - Note: Stored as key-value pairs where both keys and values are strings.
    public var metadata: [String: String]
    
    /// Computed property that provides JSON string representation of metadata.
    /// - Get: Serializes the metadata dictionary to JSON string.
    ///   Returns "{}" if serialization fails.
    /// - Set: Attempts to parse the JSON string back into a dictionary.
    ///   Resets to empty dictionary if parsing fails.
    public var dataJson: String {
        get {
            (try? JSONSerialization.data(withJSONObject: metadata, options: []))
                .flatMap { String(data: $0, encoding: .utf8) }
                ?? "{}"
        }
        set {
            if
                let data = newValue.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            {
                metadata = dict
            } else {
                metadata = [:]
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case name
        case metadata
    }

    public init(
        id: UUID,
        createdAt: Date,
        name: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.metadata = metadata
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)

        let dateString = try container.decode(String.self, forKey: .createdAt)
        guard let parsedDate = DateUtils.utcCustomFormatDate(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt,
                in: container,
                debugDescription: "Invalid date format: \(dateString)")
        }
        createdAt = parsedDate

        name = try container.decode(String.self, forKey: .name)
        metadata = try container.decode([String: String].self, forKey: .metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        let dateString = DateUtils.utcCustomFormatString(from: createdAt)
        try container.encode(dateString, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(metadata, forKey: .metadata)
    }
}
