protocol ApiService {
    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    )
    
    func createConsumer(appKey: String, completion: @escaping @Sendable (ApiErrorType) -> Void)
    
    var token: String? { get set }
}
