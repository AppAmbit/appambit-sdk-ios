import Foundation

final class DbService: @unchecked Sendable {

    private let apiService: ApiService

    init(apiService: ApiService) {
        self.apiService = apiService
    }

    func query(
        sql: String,
        params: [Any]?,
        completion: @escaping @Sendable (DbResult?, Error?) -> Void
    ) {
        apiService.executeRequest(
            DbQueryEndpoint(sql: sql, params: params),
            responseType: DbApiResponse.self
        ) { result in
            Queues.netDecode.async {
                if result.errorType != .none {
                    completion(nil, result.errorType)
                    return
                }
                guard let response = result.data else {
                    completion(nil, ApiErrorType.unknown)
                    return
                }
                completion(response.first, nil)
            }
        }
    }

    func batch(
        statements: [DbStatement],
        transaction: Bool,
        completion: @escaping @Sendable ([DbResult]?, Error?) -> Void
    ) {
        apiService.executeRequest(
            DbBatchEndpoint(statements: statements, transaction: transaction),
            responseType: DbApiResponse.self
        ) { result in
            Queues.netDecode.async {
                if result.errorType != .none {
                    completion(nil, result.errorType)
                    return
                }
                guard let response = result.data else {
                    completion(nil, ApiErrorType.unknown)
                    return
                }
                completion(response.toDbResults(), nil)
            }
        }
    }
}
