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
            completion(nil, validationError)
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
                completion(nil, error)
            case .success(let metadata):
                do {
                    completion(
                        CloudCodeResponse(
                            data: try Self.anyValue(from: response.data, statusCode: metadata.statusCode),
                            statusCode: metadata.statusCode,
                            requestId: metadata.requestId,
                            headers: metadata.headers
                        ),
                        nil
                    )
                } catch let error as CloudCodeError {
                    completion(nil, error)
                } catch {
                    completion(nil, CloudCodeError.decoding(error.localizedDescription))
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
            completion(nil, validationError)
            return cancellation
        }
        let endpoint = CloudCodeEndpoint(function: function, method: method, query: query, body: body, headers: headers)

        execute(endpoint, cancellation: cancellation) { response in
            switch Self.validateSuccessfulResponse(response) {
            case .failure(let error):
                completion(nil, error)
            case .success(let metadata):
                if metadata.statusCode == 204 {
                    // A 204 is successful but has no T to construct. Preserve the existing API contract.
                    completion(nil, nil)
                    return
                }

                guard let responseData = response.data, !responseData.isEmpty else {
                    completion(nil, .decoding("The response body is empty."))
                    return
                }

                do {
                    let value = try JSONDecoder().decode(T.self, from: responseData)
                    completion(
                        CloudCodeResult(
                            data: value,
                            statusCode: metadata.statusCode,
                            requestId: metadata.requestId,
                            headers: metadata.headers
                        ),
                        nil
                    )
                } catch {
                    completion(nil, .decoding(error.localizedDescription))
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
            let parsed = jsonValue(from: response.data)
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
            "x-app-key", "x-request-id", "x-correlation-id", "x-trace-id", "traceparent",
            "tracestate", "x-forwarded-for", "x-forwarded-host", "x-forwarded-proto",
            "x-amzn-trace-id"
        ])

        return headers?.first { key, value in
            let normalized = key.lowercased()
            return key.isEmpty || value.contains("\r") || value.contains("\n") ||
                reserved.contains(normalized) || normalized.hasPrefix("x-appambit-") ||
                normalized.hasPrefix("x-internal-")
        }?.key
    }

    private static func jsonValue(from data: Data?) -> JSONValue? {
        guard let data,
              !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) else {
            return nil
        }
        return JSONValue.from(any: object)
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
