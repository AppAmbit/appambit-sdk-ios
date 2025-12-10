import Foundation

struct LogResponse: Decodable {
    let id: Int?
    let hash: String?
    let appVersions: String?
    let classFQN: String?
    let context: [String: String]?
    let fileName: String?
    let lineNumber: String?
    let lastSeenAt: String?
    let message: String?
    let stackTrace: String?
    let type: String?
    let occurrences: Int?
    let usersAffected: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case hash
        case appVersions = "app_versions"
        case classFQN
        case context
        case fileName = "file_name"
        case lineNumber = "line_number"
        case lastSeenAt = "last_seen_at"
        case message
        case stackTrace = "stack_trace"
        case type
        case occurrences
        case usersAffected = "users_affected"
    }
}
