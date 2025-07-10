
import Foundation

public struct EventEntity: Codable {
    public let id: UUID
    public let createdAt: Date
    public var name: String
    public var metadata: [String: String]

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
        createdAt = DateUtils.utcCustomFormatDate(from: dateString)

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

    /// Raw JSON string for `metadata`
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
}
