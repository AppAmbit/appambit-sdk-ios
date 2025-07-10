import Foundation

class AppAmbitApiService: ApiService {

    private let workerQueue = DispatchQueue(label: "com.appambit.telemetry.worker", qos: .utility)
    private let storageService: StorageService

    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private var _token: String?
    private let tokenQueue = DispatchQueue(label: "com.appambit.token.access", attributes: .concurrent)

    var token: String? {
        get { tokenQueue.sync { _token } }
        set { tokenQueue.async(flags: .barrier) { self._token = newValue } }
    }

    init(storageService: StorageService) {
        self.storageService = storageService
    }

    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        workerQueue.async { [completion] in
            guard let url = URL(string: endpoint.baseUrl + endpoint.url) else {
                completion(.fail(.unknown, message: "Invalid URL"))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = endpoint.method.stringValue

            self.configureHeaders(for: &request, endpoint: endpoint)

            if let payload = endpoint.payload {
                if let log = payload as? Log {
                    let builder = MultipartFormDataBuilder()
                    builder.append(object: log.toMultipartValue())
                    let body = builder.finalize()
                    request.httpBody = body
                    request.setValue(builder.contentType(), forHTTPHeaderField: "Content-Type")

                    self.printMultipartRequest(request: request, body: body)

                } else if let logBatch = payload as? LogBatch {
                    let builder = MultipartFormDataBuilder()
                    builder.append(object: logBatch.toMultipartValue())
                    let body = builder.finalize()
                    request.httpBody = body
                    request.setValue(builder.contentType(), forHTTPHeaderField: "Content-Type")

                    self.printMultipartRequest(request: request, body: body)

                } else {
                    do {
                        let payloadDict: [String: Any]
                        if let convertible = payload as? DictionaryConvertible {
                            payloadDict = convertible.toDictionary()
                        } else if let dict = payload as? [String: Any] {
                            payloadDict = dict
                        } else {
                            completion(.fail(.unknown, message: "Payload no convertible"))
                            return
                        }

                        let jsonData = try JSONSerialization.data(withJSONObject: payloadDict, options: [.prettyPrinted])
                        request.httpBody = jsonData
                        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                        self.printJSONRequest(request: request, jsonData: jsonData)

                    } catch {
                        completion(.fail(.unknown, message: "Error serializando payload"))
                        return
                    }
                }
            }

            self.performNetworkRequest(request: request, responseType: responseType, completion: completion)
        }
    }

    func createConsumer(
        appKey: String,
        completion: @escaping @Sendable (ApiErrorType) -> Void
    ) {
        let completionCopy = completion
        workerQueue.async { [weak self] in
            guard let self = self else { return }


            let endpoint = ConsumerService.shared.registerConsumer(appKey: appKey)

            self.executeRequest(
                endpoint,
                responseType: TokenResponse.self
            ) { result in
                if let token = result.data?.token {
                    self.tokenQueue.async(flags: .barrier) {
                        self._token = token
                    }
                }
                
                do {
                    if let consumerId = result.data?.consumerId {
                        do {
                            try self.storageService.putConsumerId(String(consumerId))
                        } catch {
                            print("Error saving consumerId: \(error)")
                        }
                    }
                } catch {
                    debugPrint("Errror to Save: \(error)")
                }

                let errorType = result.errorType

                DispatchQueue.main.async {
                    completionCopy(errorType)
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

        if !endpoint.skipAuthorization, let token = self.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func performNetworkRequest<T: Decodable>(
        request: URLRequest,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            self?.workerQueue.async {
                if let error = error {
                    self?.handleFailureResponse(error: error, completion: completion)
                } else if let data = data, let response = response {
                    self?.handleSuccessResponse(data: data, response: response, responseType: responseType, completion: completion)
                } else {
                    self?.handleFailureResponse(error: URLError(.badServerResponse), completion: completion)
                }
            }
        }.resume()
    }
    

    private func handleSuccessResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: T.Type,
        completion: @escaping (ApiResult<T>) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            debugPrint("HTTP RESPONSE - CODE: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 401:
                completion(.fail(.unauthorized, message: "Unauthorized"))
                return
            case 200..<300:
                break
            default:
                completion(.fail(.unknown, message: "HTTP status \(httpResponse.statusCode)"))
                return
            }
        }

        do {
        #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("HTTP RESPONSE BODY:\n\(jsonString)")
            } else {
                print("HTTP RESPONSE BODY: (could not convert to String)")
            }
        #endif
            let decoded = try JSONDecoder().decode(T.self, from: data)
            completion(.success(decoded))
        } catch {
            completion(.fail(.unknown, message: "Decoding error: \(error.localizedDescription)"))
        }
    }

    private func handleFailureResponse<T: Decodable>(
        error: Error,
        completion: @escaping (ApiResult<T>) -> Void
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

    func printMultipartRequest(request: URLRequest, body: Data) {
        #if DEBUG
        debugPrint("HTTP - REQUEST - URL: \(request.url?.absoluteString ?? "N/A")")
        debugPrint("HTTP - REQUEST - Method: \(request.httpMethod ?? "N/A")")
        debugPrint("HTTP - REQUEST - Headers: \(request.allHTTPHeaderFields ?? [:])")
        let boundary = extractBoundary(from: request) ?? "<boundary unknown>"
        let fullBodyString = String(decoding: body, as: UTF8.self)

        print("HTTP - REQUEST - Body full length (\(body.count) bytes):\n\(fullBodyString)")

        let parts = fullBodyString.components(separatedBy: "--\(boundary)")
        for part in parts.dropFirst() {
            let lines = part.split(separator: "\r\n", maxSplits: 2, omittingEmptySubsequences: true)
            if lines.count >= 2 {
                print("KEY :\n\(lines[0])")
                print("VALUE:\n\(lines[1])")
            }
        }
        #endif
    }


    private func extractBoundary(from request: URLRequest) -> String? {
        guard let contentType = request.value(forHTTPHeaderField: "Content-Type") else { return nil }
        let prefix = "boundary="
        guard let range = contentType.range(of: prefix) else { return nil }
        return String(contentType[range.upperBound...])
    }

}
