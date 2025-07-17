import Foundation

class Log: Codable {
    var appVersion: String?
    var classFQN: String?
    var fileName: String?
    var lineNumber: Int64 = 0
    var message: String = ""
    var stackTrace: String = AppConstants.noStackTraceAvailable
    var contextJson: String = "{}"
    var context: [String: String] {
        get {
            guard let data = contextJson.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            contextJson = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? "{}"
        }
    }
    var type: LogType?
    var file: MultipartFile? = nil

    enum CodingKeys: String, CodingKey {
        case appVersion = "app_version"
        case classFQN = "classFQN"
        case fileName = "file_name"
        case lineNumber = "line_number"
        case message
        case stackTrace = "stack_trace"
        case contextJson = "context"
        case type
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appVersion = try c.decodeIfPresent(String.self, forKey: .appVersion)
        classFQN = try c.decodeIfPresent(String.self, forKey: .classFQN)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        lineNumber = try c.decodeIfPresent(Int64.self, forKey: .lineNumber) ?? 0
        message = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
        stackTrace = try c.decodeIfPresent(String.self, forKey: .stackTrace) ?? AppConstants.noStackTraceAvailable
        contextJson = try c.decodeIfPresent(String.self, forKey: .contextJson) ?? "{}"
        type = try c.decodeIfPresent(LogType.self, forKey: .type)
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(appVersion, forKey: .appVersion)
        try c.encodeIfPresent(classFQN, forKey: .classFQN)
        try c.encodeIfPresent(fileName, forKey: .fileName)
        try c.encode(lineNumber, forKey: .lineNumber)
        try c.encode(message, forKey: .message)
        try c.encode(stackTrace, forKey: .stackTrace)
        try c.encode(contextJson, forKey: .contextJson)
        try c.encodeIfPresent(type, forKey: .type)
    }

    open func toMultipartValue() -> MultipartValue {
        var dict: [String: MultipartValue] = [:]
        dict["app_version"] = .string(appVersion ?? "")
        dict["classFQN"] = .string(classFQN ?? "")
        dict["file_name"] = .string(fileName ?? "")
        dict["line_number"] = .string(String(lineNumber))
        dict["message"] = .string(message)
        dict["stack_trace"] = .string(stackTrace)
        dict["context"] = .dictionary(
            context.mapValues { .string($0) }
        )
        dict["type"] = .string(type?.rawValue ?? "")
        if let f = file {
            dict["file"] = .file(f)
        }
        return .dictionary(dict)
    }
}
