final class TokenService {
    static func createTokenEndpoint(
        storageService: StorageService? = nil,
        completion: @escaping (Result<TokenEndpoint, Error>) -> Void
    ) {
        do {
            let storage = storageService ?? ServiceContainer.shared.storageService
            guard let appKey = try storage.getAppId() else {
                completion(.failure(DatabaseErrorType.missingAppKey))
                return
            }

            guard let consumerId = try storage.getConsumerId() else {
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
