protocol ApiService {
    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @Sendable @escaping(ApiResult<T>) -> Void
    )
    
    func getNewToken(completion: @escaping @Sendable (ApiErrorType) -> Void)
    
    var token: String? { get }
    
    func setToken(_ newToken: String)
}
