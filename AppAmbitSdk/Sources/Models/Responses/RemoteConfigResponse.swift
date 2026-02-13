import Foundation

public enum RemoteConfigValue: Decodable, Sendable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }

        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }

        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }

        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }

        throw DecodingError.typeMismatch(
            RemoteConfigValue.self,
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported RemoteConfigValue type"
            )
        )
    }

    /// Helper to bridge back to `Any` if needed for dictionary usage
    public var value: Any {
        switch self {
        case .bool(let v): return v
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        }
    }
}

public struct RemoteConfigResponse: Decodable, Sendable {
    public let configs: [String: RemoteConfigValue]?

    private enum CodingKeys: String, CodingKey {
        case configs
    }
}
