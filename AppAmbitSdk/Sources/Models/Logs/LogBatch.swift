import Foundation

class LogBatch: Codable {
    var logs: [LogEntity]

    enum CodingKeys: String, CodingKey {
        case logs = "logs"
    }
    
    init(logs: [LogEntity]) {
        self.logs = logs
    }
    
    func toMultipartValue() -> MultipartValue {
        let multipartLogs = logs.map { $0.toMultipartValue() }
        return .dictionary([
            "logs": .array(multipartLogs)
        ])
    }
}
