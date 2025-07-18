import Foundation

class AppAmbitApiService: ApiService, @unchecked Sendable {
    
    private let workerQueue = DispatchQueue(label: "com.appambit.api.worker", qos: .utility)
    private let workerRenewToken = DispatchQueue(label: "com.appambit.api.renewtoken", attributes: .concurrent)
    private let tokenQueue = DispatchQueue(label: "com.appambit.token.access", attributes: .concurrent)
    private let pendingRetryQueue = DispatchQueue(label: "com.appambit.pending.retry.queue", attributes: .concurrent)
    
    private var pendingRetryActions: [(ApiErrorType) -> Void] = []
    private let storageService: StorageService
    private var _token: String?
    private var currentTokenRenewal: ((ApiErrorType) -> Void)?
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    var token: String? {
        get { tokenQueue.sync { _token } }
    }
    
    init(storageService: StorageService) {
        self.storageService = storageService
    }
    
    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @Sendable @escaping (ApiResult<T>) -> Void
    ) {
        workerQueue.async { [completion] in
            if !ServiceContainer.shared.reachabilityService.isConnected {
                completion(.fail(.unknown, message: "No internet connection"))
                return
            }
            
            guard let url = URL(string: endpoint.baseUrl + endpoint.url) else {
                completion(.fail(.unknown, message: "Invalid URL"))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.stringValue
            
            self.configureHeaders(for: &request, endpoint: endpoint)
            
            if let payload = endpoint.payload {
                if endpoint.method == .get {
                    self.handleGETWithQueryParameters(
                        payload: payload,
                        request: &request,
                        responseType: T.self,
                        completion: completion
                    )
                } else {
                    if self.isMultipartPayload(payload) {
                        self.handleMultipartPayload(payload, request: &request)
                    } else {
                        self.handleJSONPayload(
                            payload,
                            request: &request,
                            responseType: T.self,
                            completion: completion
                        )
                    }
                }
            }
            
            let isTokenEndpoint = endpoint is TokenEndpoint
            let skipAuth = endpoint.skipAuthorization
           
            self.processResponse(request: request, responseType: responseType) { result in
                
                self.workerQueue.async {
                    switch (result.errorType, result.message) {
                    case (.unauthorized, _) where !isTokenEndpoint:
                        self.handleTokenRefresh(
                            originalRequest: request,
                            skipAuth: skipAuth,
                            responseType: responseType,
                            completion: completion
                        )
                    default:
                        completion(result)
                    }
                }
            }
        }
    }
    
    func getNewToken(completion: @escaping @Sendable (ApiErrorType) -> Void) {
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            
            TokenService.createTokenEndpoint { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                    case .success(let endpoint):
                        self.fetchToken(using: endpoint, completion: completion)
                    case .failure:
                        DispatchQueue.main.async {
                            completion(.unknown)
                        }
                }
            }
        }
    }
    
    func setToken(_ newToken: String) {
        tokenQueue.async(flags: .barrier) {
            self._token = newToken
        }
    }

    private func handleTokenRefresh<T: Decodable>(
        originalRequest: URLRequest?,
        skipAuth: Bool,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        let retryAction: (ApiErrorType) -> Void = { [weak self] error in
            guard let self = self else { return }
            if error == .none, let originalRequest = originalRequest {
                var newRequest = originalRequest
                if !skipAuth, let token = self.token {
                    newRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                self.processResponse(request: newRequest, responseType: responseType, completion: completion)
            } else {
                completion(.fail(error, message: "Fallo en la renovación del token"))
            }
        }
        
        pendingRetryQueue.async(flags: .barrier) {
            self.pendingRetryActions.append(retryAction)
        }
        
        workerQueue.async(flags: .barrier) {
            if self.currentTokenRenewal == nil {
                self.currentTokenRenewal = { [weak self] error in
                    guard let self = self else { return }
                    self.pendingRetryQueue.async(flags: .barrier) {
                        let actions = self.pendingRetryActions
                        self.pendingRetryActions.removeAll()
                        for action in actions {
                            action(error)
                        }
                    }
                    self.currentTokenRenewal = nil
                }
                
                self.getNewToken { error in
                    self.workerQueue.async(flags: .barrier) {
                        self.currentTokenRenewal?(error)
                    }
                }
            }
        }
    }
    
    private func handleFailedRenewalResult<T>(_ type: T.Type, result: ApiErrorType) -> ApiResult<T> {
        if result == .networkUnavailable {
            debugPrint("Cannot retry request: no internet after token renewal")
            return .fail(.networkUnavailable, message: "No internet after token renewal")
        }
        
        debugPrint("Could not renew token. Cleaning up")
        clearToken()
        return .fail(result, message: "Token renewal failed")
    }
    
    private func handleTokenRenewalException<T>(_ type: T.Type, error: Error) -> ApiResult<T> {
        debugPrint("Error renewing token: \(error)")
        clearToken()
        return .fail(.unknown, message: "Token renewal failed")
    }
    
    private func isRenewSuccess(_ error: ApiErrorType) -> Bool {
        return error == .none
    }
    
    private func isRenewingToken() -> Bool {
        return currentTokenRenewal != nil
    }
    
    private func handleGETWithQueryParameters<T: Decodable>(
        payload: Any,
        request: inout URLRequest,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        guard var urlComponents = URLComponents(url: request.url!, resolvingAgainstBaseURL: false) else {
            completion(.fail(.unknown, message: "Invalid URL"))
            return
        }
        
        var queryItems = [URLQueryItem]()
        
        if let dictConvertible = payload as? DictionaryConvertible {
            let dictionary = dictConvertible.toDictionary()
            queryItems = dictionary.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        } else if let dictionary = payload as? [String: Any] {
            queryItems = dictionary.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }
        
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let urlWithQueryParams = urlComponents.url else {
            completion(.fail(.unknown, message: "Invalid URL with query parameters"))
            return
        }
        
        request.url = urlWithQueryParams
        
        #if DEBUG
        debugPrint("HTTP - REQUEST - URL with QueryParams: \(request.url?.absoluteString ?? "N/A")")
        #endif
    }
    
    /// Determines whether the payload is of the multipart type (Log or LogBatch)
    private func isMultipartPayload(_ payload: Any) -> Bool {
        return payload is Log || payload is LogBatch
    }
    
    /// Process multipart payloads (Log or LogBatch)
    private func handleMultipartPayload(_ payload: Any, request: inout URLRequest) {
        let builder = MultipartFormDataBuilder()
        
        if let log = payload as? Log {
            builder.append(object: log.toMultipartValue())
        } else if let logBatch = payload as? LogBatch {
            builder.append(object: logBatch.toMultipartValue())
        }
        
        let body = builder.finalize()
        request.httpBody = body
        request.setValue(builder.contentType(), forHTTPHeaderField: "Content-Type")
        printMultipartRequest(request: request, body: body)
    }
    
    /// Processes JSON payloads (dictionaries or objects convertible to dictionaries)
    private func handleJSONPayload<T: Decodable>(
        _ payload: Any,
        request: inout URLRequest,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        do {
            let payloadDict = try convertToDictionary(payload: payload)
            let jsonData = try JSONSerialization.data(withJSONObject: payloadDict, options: [.prettyPrinted])
            
            request.httpBody = jsonData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            printJSONRequest(request: request, jsonData: jsonData)
            
        } catch let error as ApiErrorType {
            completion(.fail(error, message: "Payload no convertible"))
        } catch {
            completion(.fail(.unknown, message: "Error serializando payload: \(error.localizedDescription)"))
        }
    }
    
    /// Converts the payload to a dictionary [String: Any]
    private func convertToDictionary(payload: Any) throws -> [String: Any] {
        if let convertible = payload as? DictionaryConvertible {
            return convertible.toDictionary()
        } else if let dict = payload as? [String: Any] {
            return dict
        }
        throw ApiErrorType.unknown
    }
    
    private func clearToken() {
        self.tokenQueue.async(flags: .barrier) {
            self._token = ""
        }
    }
        
    private func fetchToken(using endpoint: TokenEndpoint, completion: @escaping @Sendable (ApiErrorType) -> Void) {
        executeRequest(endpoint, responseType: TokenResponse.self) { [weak self] result in
            guard let self = self else { return }
            
            let errorType = result.errorType
            
            if let token = result.data?.token {
                self.tokenQueue.async(flags: .barrier) {
                    self._token = token
                    DispatchQueue.main.async {
                        completion(errorType)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(errorType)
                }
            }
        }
    }
    
    private func configureHeaders(for request: inout URLRequest, endpoint: Endpoint) {
        if let headers = endpoint.customHeader {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        self.addAuthorizationHeaderIfNeeded(for: &request, endpoint: endpoint)
    }
    
    private func addAuthorizationHeaderIfNeeded(for request: inout URLRequest, endpoint: Endpoint) {
        if !endpoint.skipAuthorization, let token = self.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    private func processResponse<T: Decodable>(
        request: URLRequest,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.workerQueue.async {
                let result = Result<T, Error> { try self.processData(data, response, error) }
                
                switch result {
                case .success(let decoded):
                    completion(ApiResult.success(decoded))
                    
                case .failure(let error as ApiExceptions):
                    let apiErrorType: ApiErrorType
                    switch error {
                    case .unauthorized:
                        apiErrorType = .unauthorized
                    case .networkError:
                        apiErrorType = .networkUnavailable
                    default:
                        apiErrorType = .unknown
                    }
                    completion(.fail(apiErrorType, message: error.localizedDescription))

                    
                case .failure(let error):
                    completion(ApiResult.fail(.unknown, message: error.localizedDescription))
                }
            }
        }.resume()
    }

    private func processData<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?) throws -> T {
        if let error = error {
            if let urlError = error as? URLError {
                throw ApiExceptions.networkError(urlError)
            }
            throw ApiExceptions.networkError(URLError(.unknown))
        }
        
        guard let data = data, let response = response else {
            throw URLError(.badServerResponse)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 401:
                throw ApiExceptions.unauthorized
            case 200..<300:
                break
            default:
                throw ApiExceptions.httpError(
                    statusCode: httpResponse.statusCode,
                    message: "HTTP error"
                )
            }
        }
        
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("HTTP RESPONSE BODY:\n\(jsonString)")
        }
        #endif
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiExceptions.httpError(
                statusCode: -1,
                message: "Decode"
            )
        }
        
    }
    
    private func checkStatusCodeFrom(response: URLResponse) throws {
        if let httpResponse = response as? HTTPURLResponse {
            debugPrint("HTTP RESPONSE - CODE: \(httpResponse.statusCode)")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            switch httpResponse.statusCode {
            case 401:
                throw ApiExceptions.unauthorized
            case 200..<300:
                break
            default:
                throw ApiExceptions.httpError(statusCode: httpResponse.statusCode, message: "Unexpected error during request")
            }
        }
    }
    
    private func handleFailureResponse<T: Decodable>(
        error: Error,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            completion(.fail(.networkUnavailable, message: "No internet connection"))
        } else {
            completion(.fail(.unknown, message: "Unknown error: \(error.localizedDescription)"))
        }
    }
    
    private func printJSONRequest(request: URLRequest, jsonData: Data) {
    #if DEBUG
        debugPrint("HTTP - REQUEST - URL: \(request.url?.absoluteString ?? "N/A")")
        debugPrint("HTTP - REQUEST - Method: \(request.httpMethod ?? "N/A")")
        debugPrint("HTTP - REQUEST - Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("HTTP - REQUEST - JSON Body:\n\(jsonString)")
        }else {
            print("HTTP - REQUEST - JSON Body: (could not convert to String)")
        }
    #endif
    }
    
    private func printMultipartRequest(request: URLRequest, body: Data) {
    #if DEBUG
        debugPrint("HTTP - REQUEST - URL: \(request.url?.absoluteString ?? "N/A")")
        debugPrint("HTTP - REQUEST - Method: \(request.httpMethod ?? "N/A")")
        debugPrint("HTTP - REQUEST - Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        let fullBodyString = String(decoding: body, as: UTF8.self)
        print("HTTP - REQUEST - Body full length (\(body.count) bytes):\n\(fullBodyString)")
        
    #endif
    }
    
    private func extractBoundary(from request: URLRequest) -> String? {
        guard let contentType = request.value(forHTTPHeaderField: "Content-Type") else { return nil }
        let prefix = "boundary="
        guard let range = contentType.range(of: prefix) else { return nil }
        return String(contentType[range.upperBound...])
    }
}
