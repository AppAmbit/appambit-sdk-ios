import Foundation

public struct Event: Codable {
    public var name: String
    public private(set) var metadata: [String: String]

    public init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }

    public var dataJson: String {
        get {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata, options: []) else {
                return "{}"
            }
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        set {
            guard
                let data = newValue.data(using: .utf8),
                let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String]
            else {
                metadata = [:]
                return
            }
            metadata = dict
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case metadata = "metadata"
    }
}

