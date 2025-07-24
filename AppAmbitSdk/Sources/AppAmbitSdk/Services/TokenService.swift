final class TokenService {
    static func createTokenEndpoint(
        completion: @escaping (Result<TokenEndpoint, Error>) -> Void
    ) {
        do {
            guard let appKey = try ServiceContainer.shared.storageService.getAppId() else {
                completion(.failure(DatabaseErrorType.missingAppKey))
                return
            }

            guard let consumerId = try ServiceContainer.shared.storageService.getConsumerId() else {
                completion(.failure(DatabaseErrorType.missingConsumerId))
                return
            }

            let token = ConsumerToken(appKey: appKey, consumerId: consumerId)
            completion(.success(TokenEndpoint(token: token)))
        } catch {
            completion(.failure(error))
        }
    }
}
