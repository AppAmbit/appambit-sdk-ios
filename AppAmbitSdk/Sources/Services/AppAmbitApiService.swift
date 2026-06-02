import Foundation
import Network
import Security

final class AppAmbitApiService: ApiService, @unchecked Sendable {

    // MARK: - State

    private let storageService: StorageService
    private var _token: String?
    private var pendingRetryActions: [(ApiErrorType) -> Void] = []
    private var currentTokenRenewal: ((ApiErrorType) -> Void)?

    // MARK: - Networking

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: config)
    }()

    // MARK: - Init

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    // MARK: - Token (thread-safe using internal queue)

    var token: String? {
        Queues.token.sync { _token }
    }

    func setToken(_ newToken: String) {
        Queues.token.async(flags: .barrier) { self._token = newToken }
    }

    private func clearToken() {
        Queues.token.async(flags: .barrier) { self._token = "" }
    }

    // MARK: - Public API

    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @Sendable @escaping (ApiResult<T>) -> Void
    ) {
        Queues.state.async { [weak self] in
            guard let self else { return }

            if !ServiceContainer.shared.reachabilityService.isConnected() {
                completion(.fail(.unknown, message: "No internet connection"))
                return
            }

            // CMS GET requests use raw HTTP/1.1 to preserve literal brackets in filter params.
            // Foundation's URL always encodes [ ] as %5B %5D; the CMS server requires literal brackets.
            if let cmsEndpoint = endpoint as? CmsEndpoint, endpoint.method == .get {
                self.executeCmsRawRequest(cmsEndpoint, responseType: responseType, completion: completion)
                return
            }

            guard let url = URL(string: endpoint.baseUrl + endpoint.url) else {
                completion(.fail(.unknown, message: "Invalid URL"))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.stringValue

            #if DEBUG
            if endpoint is CmsEndpoint {
                AppAmbitLogger.log(message: "CMS REQUEST URL: \(url.absoluteString)")
            }
            #endif

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
                Queues.state.async {
                    switch result.errorType {
                    case .unauthorized where !isTokenEndpoint:
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
        Queues.state.async { [weak self] in
            guard let self else { return }

            TokenService.createTokenEndpoint { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let endpoint):
                    self.fetchToken(using: endpoint, completion: completion)
                case .failure:
                    DispatchQueue.main.async { completion(.unknown) }
                }
            }
        }
    }

    // MARK: - Refresh token

    private func handleTokenRefresh<T: Decodable>(
        originalRequest: URLRequest?,
        skipAuth: Bool,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        let retryAction: (ApiErrorType) -> Void = { [weak self] error in
            guard let self else { return }
            if error == .none, let originalRequest {
                var newRequest = originalRequest
                if !skipAuth, let token = self.token {
                    newRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                self.processResponse(request: newRequest, responseType: responseType, completion: completion)
            } else {
                completion(.fail(error, message: "Token renewal failure"))
            }
        }

        Queues.state.async {
            self.pendingRetryActions.append(retryAction)
        }

        Queues.state.async(flags: .barrier) {
            if self.currentTokenRenewal == nil {
                self.currentTokenRenewal = { [weak self] error in
                    guard let self else { return }
                    Queues.state.async(flags: .barrier) {
                        let actions = self.pendingRetryActions
                        self.pendingRetryActions.removeAll()
                        actions.forEach { $0(error) }
                        self.currentTokenRenewal = nil
                    }
                }

                self.getNewToken { error in
                    Queues.state.async {
                        self.currentTokenRenewal?(error)
                    }
                }
            }
        }
    }

    // MARK: - Token fetch

    private func fetchToken(using endpoint: TokenEndpoint, completion: @escaping @Sendable (ApiErrorType) -> Void) {
        executeRequest(endpoint, responseType: TokenResponse.self) { [weak self] result in
            guard let self else { return }
            let errorType = result.errorType

            if let token = result.data?.token {
                Queues.token.async(flags: .barrier) {
                    self._token = token
                    DispatchQueue.main.async { completion(errorType) }
                }
            } else {
                DispatchQueue.main.async { completion(errorType) }
            }
        }
    }

    // MARK: - Request helpers

    private func configureHeaders(for request: inout URLRequest, endpoint: Endpoint) {
        if let headers = endpoint.customHeader {
            for (k, v) in headers {
                request.addValue(v, forHTTPHeaderField: k)
            }
        }
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        addAuthorizationHeaderIfNeeded(for: &request, endpoint: endpoint)
    }

    private func addAuthorizationHeaderIfNeeded(for request: inout URLRequest, endpoint: Endpoint) {
        if endpoint is CmsEndpoint {
            if let appId = try? ServiceContainer.shared.storageService.getAppId() {
                request.addValue(appId, forHTTPHeaderField: "X-App-Key")
            }
            return
        }
        
        if !endpoint.skipAuthorization, let token = self.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
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
        AppAmbitLogger.log(message: "HTTP - REQUEST - URL with QueryParams: \(request.url?.absoluteString ?? "N/A")")
        #endif
    }

    private func isMultipartPayload(_ payload: Any) -> Bool {
        payload is Log || payload is LogBatch
    }

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

    private func handleJSONPayload<T: Decodable>(
        _ payload: Any,
        request: inout URLRequest,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        do {
            let payloadDict = try convertToDictionary(payload: payload)
            guard JSONSerialization.isValidJSONObject(payloadDict) else {
                return completion(.fail(.unknown, message: "The payload object is not a valid JSON"))
            }
            let jsonData = try JSONSerialization.data(withJSONObject: payloadDict, options: [.prettyPrinted])
            request.httpBody = jsonData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            printJSONRequest(request: request, jsonData: jsonData)
        } catch let error as ApiErrorType {
            completion(.fail(error, message: "Payload not convertible"))
        } catch {
            completion(.fail(.unknown, message: "Error serializing payload: \(error.localizedDescription)"))
        }
    }

    private func convertToDictionary(payload: Any) throws -> [String: Any] {
        if let convertible = payload as? DictionaryConvertible { return convertible.toDictionary() }
        if let dict = payload as? [String: Any] { return dict }
        throw ApiErrorType.unknown
    }

    // MARK: - Low level response/decoding

    private func processResponse<T: Decodable>(
        request: URLRequest,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            Queues.netDecode.async {
                let result = Result<T, Error> { try self.checkStatusCodeFrom(data, response, error) }

                switch result {
                case .success(let decoded):
                    completion(.success(decoded))

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
                    completion(.fail(.unknown, message: error.localizedDescription))
                }
            }
        }.resume()
    }

    private func checkStatusCodeFrom<T: Decodable>(_ data: Data?, _ response: URLResponse?, _ error: Error?) throws -> T {
        if let error {
            if let urlError = error as? URLError {
                throw ApiExceptions.networkError(urlError)
            }
            throw ApiExceptions.networkError(URLError(.unknown))
        }

        guard let data, let response else {
            throw URLError(.badServerResponse)
        }

        if let httpResponse = response as? HTTPURLResponse {
            AppAmbitLogger.log(message: "HTTP RESPONSE CODE: \(httpResponse.statusCode)")
            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("HTTP RESPONSE BODY:\n\(jsonString)")
            }
            #endif

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

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiExceptions.httpError(
                statusCode: -1,
                message: "Decode: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Debug prints

    private func printJSONRequest(request: URLRequest, jsonData: Data) {
        #if DEBUG
        AppAmbitLogger.log(message: "HTTP - REQUEST - URL: \(request.url?.absoluteString ?? "N/A")")
        AppAmbitLogger.log(message: "HTTP - REQUEST - Method: \(request.httpMethod ?? "N/A")")
        AppAmbitLogger.log(message: "HTTP - REQUEST - Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("HTTP - REQUEST - JSON Body:\n\(jsonString)")
        } else {
            print("HTTP - REQUEST - JSON Body: (could not convert to String)")
        }
        #endif
    }

    private func printMultipartRequest(request: URLRequest, body: Data) {
        #if DEBUG
        AppAmbitLogger.log(message: "HTTP - REQUEST - URL: \(request.url?.absoluteString ?? "N/A")")
        AppAmbitLogger.log(message: "HTTP - REQUEST - Method: \(request.httpMethod ?? "N/A")")
        AppAmbitLogger.log(message: "HTTP - REQUEST - Headers: \(request.allHTTPHeaderFields ?? [:])")

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

    // MARK: - CMS raw HTTP/1.1 (bypasses Foundation URL encoding so brackets stay literal)

    private func executeCmsRawRequest<T: Decodable>(
        _ endpoint: CmsEndpoint,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        guard let cmsURL = URL(string: endpoint.baseUrl), let host = cmsURL.host else {
            completion(.fail(.unknown, message: "Invalid CMS base URL"))
            return
        }
        let basePath = cmsURL.path
        let rawPath = (basePath + endpoint.url)
            .replacingOccurrences(of: "%5B", with: "[", options: .caseInsensitive)
            .replacingOccurrences(of: "%5D", with: "]", options: .caseInsensitive)

        guard let appKey = try? ServiceContainer.shared.storageService.getAppId(), !appKey.isEmpty else {
            completion(.fail(.unauthorized, message: "SDK not yet initialized — X-App-Key unavailable"))
            return
        }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_add_tls_application_protocol(tlsOptions.securityProtocolOptions, "http/1.1")

        let connection = NWConnection(host: NWEndpoint.Host(host), port: 443, using: NWParameters(tls: tlsOptions))

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.sendCmsRawHTTP(connection: connection, host: host, path: rawPath,
                                    appKey: appKey, responseType: responseType, completion: completion)
            case .failed(let error):
                connection.cancel()
                Queues.netDecode.async { completion(.fail(.networkUnavailable, message: error.localizedDescription)) }
            default:
                break
            }
        }
        connection.start(queue: Queues.netDecode)
    }

    private func sendCmsRawHTTP<T: Decodable>(
        connection: NWConnection,
        host: String,
        path: String,
        appKey: String,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        let req = "GET \(path) HTTP/1.1\r\nHost: \(host)\r\nX-App-Key: \(appKey)\r\nAccept: application/json\r\nConnection: close\r\n\r\n"
        #if DEBUG
        AppAmbitLogger.log(message: "CMS REQUEST URL: https://\(host)\(path)")
        #endif
        connection.send(content: req.data(using: .utf8), completion: .contentProcessed({ _ in }))
        readCmsRawResponse(connection: connection, buffer: Data()) { [weak self] result in
            connection.cancel()
            switch result {
            case .success(let data):
                self?.parseCmsRawResponse(data: data, responseType: responseType, completion: completion)
            case .failure(let err):
                completion(.fail(.networkUnavailable, message: err.localizedDescription))
            }
        }
    }

    private func readCmsRawResponse(
        connection: NWConnection,
        buffer: Data,
        completion: @escaping (Result<Data, NWError>) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] chunk, _, isComplete, error in
            if let error { completion(.failure(error)); return }
            var data = buffer
            if let chunk { data.append(chunk) }
            if isComplete {
                completion(.success(data))
            } else {
                self?.readCmsRawResponse(connection: connection, buffer: data, completion: completion)
            }
        }
    }

    private func parseCmsRawResponse<T: Decodable>(
        data: Data,
        responseType: T.Type,
        completion: @escaping @Sendable (ApiResult<T>) -> Void
    ) {
        let sep = Data("\r\n\r\n".utf8)
        guard let sepRange = data.range(of: sep),
              let headerStr = String(data: data[..<sepRange.lowerBound], encoding: .utf8) else {
            completion(.fail(.unknown, message: "Malformed HTTP response"))
            return
        }
        let statusCode = Int(headerStr.components(separatedBy: "\r\n")
            .first?.components(separatedBy: " ").dropFirst().first ?? "0") ?? 0
        var body = Data(data[sepRange.upperBound...])
        if headerStr.lowercased().contains("transfer-encoding: chunked") {
            body = decodeCmsChunkedBody(body)
        }
        #if DEBUG
        AppAmbitLogger.log(message: "HTTP RESPONSE CODE: \(statusCode)")
        if let s = String(data: body, encoding: .utf8) { print("HTTP RESPONSE BODY:\n\(s)") }
        #endif
        switch statusCode {
        case 401:
            completion(.fail(.unauthorized, message: "Unauthorized"))
        case 200..<300:
            do {
                completion(.success(try JSONDecoder().decode(responseType, from: body)))
            } catch {
                completion(.fail(.unknown, message: "Decode: \(error.localizedDescription)"))
            }
        default:
            completion(.fail(.unknown, message: "HTTP \(statusCode)"))
        }
    }

    private func decodeCmsChunkedBody(_ data: Data) -> Data {
        var result = Data()
        var cursor = data.startIndex
        let crlf = Data("\r\n".utf8)
        while cursor < data.endIndex,
              let nl = data.range(of: crlf, in: cursor..<data.endIndex),
              let size = Int(String(data: data[cursor..<nl.lowerBound], encoding: .utf8)?
                  .trimmingCharacters(in: .whitespaces) ?? "", radix: 16), size > 0 {
            cursor = nl.upperBound
            let end = data.index(cursor, offsetBy: size, limitedBy: data.endIndex) ?? data.endIndex
            result.append(data[cursor..<end])
            cursor = end
            if cursor < data.endIndex, data[cursor...].starts(with: crlf) {
                cursor = data.index(cursor, offsetBy: 2)
            }
        }
        return result
    }
}
