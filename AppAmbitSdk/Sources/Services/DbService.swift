import Foundation

final class DbService: @unchecked Sendable {

    private let apiService: ApiService

    init(apiService: ApiService) {
        self.apiService = apiService
    }

    @discardableResult
    func query(
        sql: String,
        params: [Any]?,
        completion: @escaping @Sendable (DbResult?, Error?) -> Void
    ) -> DbCancellationToken {
        let token = DbCancellationToken()
        apiService.executeRequest(
            DbQueryEndpoint(sql: sql, params: params),
            responseType: DbApiResponse.self
        ) { result in
            Queues.netDecode.async {
                guard !token.isCancelled else { return }
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
        return token
    }

    @discardableResult
    func batch(
        statements: [DbStatement],
        transaction: Bool,
        completion: @escaping @Sendable ([DbResult]?, Error?) -> Void
    ) -> DbCancellationToken {
        let token = DbCancellationToken()
        apiService.executeRequest(
            DbBatchEndpoint(statements: statements, transaction: transaction),
            responseType: DbApiResponse.self
        ) { result in
            Queues.netDecode.async {
                guard !token.isCancelled else { return }
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
        return token
    }
}
