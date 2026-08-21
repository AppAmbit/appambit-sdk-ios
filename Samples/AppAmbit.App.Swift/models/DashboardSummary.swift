import AppAmbit

struct DashboardSummary: Decodable {
    let taskCount: Int?
    let posts: [JSONValue]?

    enum CodingKeys: String, CodingKey {
        case taskCount = "task_count"
        case posts
    }
}
