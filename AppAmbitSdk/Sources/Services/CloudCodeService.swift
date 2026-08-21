import Foundation

final class CloudCodeService: @unchecked Sendable {
    static let defaultTimeout: TimeInterval = AppConstants.cloudCodeTimeout

    private let transport: HTTPTransport

    init(transport: HTTPTransport) {
        self.transport = transport
    }

    @discardableResult
    func call(
        function: String,
        method: CloudCodeHttpMethod,
        query: [String: String]?,
        body: [String: Any]?,
        headers: [String: String]?,
        completion: @escaping @Sendable (CloudCodeResponse?, Error?) -> Void
    ) -> CloudCodeCancellationToken {
        let cancellation = CloudCodeCancellationToken()

        if let validationError = validationError(function: function, body: body, headers: headers) {
            deliverOnMain(cancellation: cancellation) { completion(nil, validationError) }
            return cancellation
        }

        let endpoint = CloudCodeEndpoint(
            function: function,
            method: method,
            query: query,
            body: body,
            headers: headers
        )

        execute(endpoint, cancellation: cancellation) { response in
            switch Self.validateSuccessfulResponse(response) {
            case .failure(let error):
                self.deliverOnMain(cancellation: cancellation) { completion(nil, error) }
            case .success(let metadata):
                do {
                    let data = try Self.anyValue(from: response.data, statusCode: metadata.statusCode)
                    let cloudResponse = CloudCodeResponse(
                        data: data,
                        statusCode: metadata.statusCode,
                        requestId: metadata.requestId,
                        headers: metadata.headers
                    )
                    self.deliverOnMain(cancellation: cancellation) {
                        completion(cloudResponse, nil)
                    }
                } catch let error as CloudCodeError {
                    self.deliverOnMain(cancellation: cancellation) { completion(nil, error) }
                } catch {
                    self.deliverOnMain(cancellation: cancellation) {
                        completion(nil, CloudCodeError.decoding(error.localizedDescription))
                    }
                }
            }
        }

        return cancellation
    }

    @discardableResult
    func call<T: Decodable>(
        function: String,
        method: CloudCodeHttpMethod,
        query: [String: String]?,
        body: [String: Any]?,
        headers: [String: String]?,
        as type: T.Type,
        completion: @escaping @Sendable (CloudCodeResult<T>?, CloudCodeError?) -> Void
    ) -> CloudCodeCancellationToken {
        let cancellation = CloudCodeCancellationToken()

        if let validationError = validationError(function: function, body: body, headers: headers) {
            deliverOnMain(cancellation: cancellation) { completion(nil, validationError) }
            return cancellation
        }
        let endpoint = CloudCodeEndpoint(function: function, method: method, query: query, body: body, headers: headers)

        execute(endpoint, cancellation: cancellation) { response in
            switch Self.validateSuccessfulResponse(response) {
            case .failure(let error):
                self.deliverOnMain(cancellation: cancellation) { completion(nil, error) }
            case .success(let metadata):
                guard let responseData = response.data, !responseData.isEmpty else {
                    self.deliverOnMain(cancellation: cancellation) {
                        completion(
                            CloudCodeResult(
                                data: nil,
                                statusCode: metadata.statusCode,
                                requestId: metadata.requestId,
                                headers: metadata.headers
                            ),
                            nil
                        )
                    }
                    return
                }

                do {
                    let value = try JSONDecoder().decode(T.self, from: responseData)
                    let result = CloudCodeResult(
                        data: value,
                        statusCode: metadata.statusCode,
                        requestId: metadata.requestId,
                        headers: metadata.headers
                    )
                    self.deliverOnMain(cancellation: cancellation) {
                        completion(result, nil)
                    }
                } catch {
                    self.deliverOnMain(cancellation: cancellation) {
                        completion(nil, .decoding(error.localizedDescription))
                    }
                }
            }
        }

        return cancellation
    }

    private func execute(
        _ endpoint: CloudCodeEndpoint,
        cancellation: CloudCodeCancellationToken,
        completion: @escaping @Sendable (HTTPTransportResponse) -> Void
    ) {
        transport.executeRawRequest(endpoint, timeout: Self.defaultTimeout) { response in
            guard !cancellation.isCancelled else { return }
            completion(response)
        }
    }

    private func deliverOnMain(
        cancellation: CloudCodeCancellationToken,
        _ completion: @escaping @Sendable () -> Void
    ) {
        DispatchQueue.main.async {
            guard !cancellation.isCancelled else { return }
            completion()
        }
    }

    private func validationError(function: String, body: [String: Any]?, headers: [String: String]?) -> CloudCodeError? {
        if !isValidFunction(function) { return .invalidFunction(function) }
        if let invalidHeader = invalidReservedHeader(in: headers) { return .invalidHeader(invalidHeader) }
        if let body, !JSONSerialization.isValidJSONObject(body) { return .invalidBody }
        return nil
    }

    private static func validateSuccessfulResponse(
        _ response: HTTPTransportResponse
    ) -> Result<(statusCode: Int, headers: [String: String], requestId: String?), CloudCodeError> {
        if let error = response.error {
            return .failure(transportError(from: error))
        }
        guard let statusCode = response.statusCode else {
            return .failure(.decoding("Missing HTTP status code."))
        }
        guard (200..<300).contains(statusCode) else {
            let parsed = jsonObjectOrArray(from: response.data)
            let rawBody = parsed == nil ? response.data.flatMap { String(data: $0, encoding: .utf8) } : nil
            return .failure(.http(statusCode: statusCode, body: parsed, rawBody: rawBody, requestId: requestId(from: response)))
        }
        return .success((statusCode, response.headers, requestId(from: response)))
    }

    private static func transportError(from error: Error) -> CloudCodeError {
        if let error = error as? ApiExceptions, case .invalidURL = error { return .invalidURL }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timedOut
            default:
                return .transport(urlError.localizedDescription)
            }
        }
        return .transport(error.localizedDescription)
    }

    private func isValidFunction(_ function: String) -> Bool {
        guard !function.isEmpty, !function.contains("/") else { return false }
        return !function.unicodeScalars.contains { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar) ||
            CharacterSet.controlCharacters.contains(scalar)
        }
    }

    private func invalidReservedHeader(in headers: [String: String]?) -> String? {
        let reserved = Set([
            "authorization", "cookie", "host", "content-length", "content-type", "accept",
            "x-app-key", "x-request-id"
        ])

        return headers?.first { key, value in
            let normalized = key.lowercased()
            return key.isEmpty || value.contains("\r") || value.contains("\n") ||
                reserved.contains(normalized)
        }?.key
    }

    private static func jsonObjectOrArray(from data: Data?) -> JSONValue? {
        guard let data,
              !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) else {
            return nil
        }
        let value = JSONValue.from(any: object)
        switch value {
        case .object, .array:
            return value
        default:
            return nil
        }
    }

    private static func anyValue(from data: Data?, statusCode: Int) throws -> Any {
        guard statusCode != 204 else { return NSNull() }
        guard let data, !data.isEmpty else { return NSNull() }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            return JSONValue.from(any: object).toAny()
        } catch {
            throw CloudCodeError.decoding("The response body is not valid JSON.")
        }
    }

    private static func requestId(from response: HTTPTransportResponse) -> String? {
        if let header = response.headers.first(where: { $0.key.caseInsensitiveCompare("X-Request-Id") == .orderedSame })?.value {
            return header
        }
        guard let data = response.data,
              let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else { return nil }
        return object["request_id"] as? String
    }
}
