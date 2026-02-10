import Foundation

public enum RemoteConfigValue: Decodable, Sendable {
    case bool(Bool)
    case string(String)
    case int(Int)
    case double(Double)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                RemoteConfigValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Value is not a valid RemoteConfigValue type (Bool, Int, Double, String)"
                )
            )
        }
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
