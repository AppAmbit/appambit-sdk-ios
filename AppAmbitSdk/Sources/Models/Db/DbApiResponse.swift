import Foundation

struct DbApiResultData: Decodable {
    let columns: [String]?
    let rows: [[DbValue]]?
    let rowsRead: Int?
    let rowsWritten: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case columns, rows, error
        case rowsRead    = "rows_read"
        case rowsWritten = "rows_written"
    }

    func toDbResult() -> DbResult {
        let cols = columns ?? []
        let anyRows: [[Any]] = (rows ?? []).map { $0.map { $0.anyValue } }
        return DbResult(
            columns: cols,
            rows: anyRows,
            rowsRead: rowsRead ?? 0,
            rowsWritten: rowsWritten ?? 0,
            error: error
        )
    }
}

struct DbApiResponse: Decodable {
    let results: [DbApiResultData]
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case results
        case requestId = "request_id"
    }

    var first: DbResult? { results.first?.toDbResult() }

    func toDbResults() -> [DbResult] { results.map { $0.toDbResult() } }
}
