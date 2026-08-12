import Foundation

final class CloudCodeService: @unchecked Sendable {
    static let defaultTimeout: TimeInterval = 60

    private let transport: CloudCodeTransport

    init(transport: CloudCodeTransport) {
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
                completion(
                    CloudCodeResponse(
                        data: Self.anyValue(from: response.data),
                        statusCode: metadata.statusCode,
                        requestId: metadata.requestId
                    ),
                    nil
                )
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
                    completion(CloudCodeResult(data: value, statusCode: metadata.statusCode, requestId: metadata.requestId), nil)
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
        completion: @escaping @Sendable (CloudCodeTransportResponse) -> Void
    ) {
        transport.executeCloudCodeRequest(endpoint, timeout: Self.defaultTimeout) { response in
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
        _ response: CloudCodeTransportResponse
    ) -> Result<(statusCode: Int, requestId: String?), CloudCodeError> {
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
        return .success((statusCode, requestId(from: response)))
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
        !function.isEmpty && !function.contains("/")
    }

    private func invalidReservedHeader(in headers: [String: String]?) -> String? {
        let reserved = Set([
            "authorization", "cookie", "host", "content-length", "content-type", "accept",
            "x-app-key", "x-request-id", "x-forwarded-for", "x-forwarded-host",
            "x-forwarded-proto", "x-amzn-trace-id"
        ])
        return headers?.keys.first { reserved.contains($0.lowercased()) }
    }

    private static func jsonValue(from data: Data?) -> JSONValue? {
        guard let data,
              !data.isEmpty else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) else {
            return nil
        }
        return JSONValue.from(any: object)
    }

    private static func anyValue(from data: Data?) -> Any {
        guard let data, !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) else {
            return NSNull()
        }
        return JSONValue.from(any: object).toAny()
    }

    private static func requestId(from response: CloudCodeTransportResponse) -> String? {
        if let header = response.headers.first(where: { $0.key.caseInsensitiveCompare("X-Request-Id") == .orderedSame })?.value {
            return header
        }
        guard let data = response.data,
              let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else { return nil }
        return object["request_id"] as? String
    }
}
