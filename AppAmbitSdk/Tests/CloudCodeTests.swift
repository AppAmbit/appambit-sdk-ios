import Foundation
import XCTest
@testable import AppAmbit

final class CloudCodeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CloudCode.resetForTesting()
    }

    override func tearDown() {
        CloudCode.resetForTesting()
        super.tearDown()
    }

    func testCallBeforeAppAmbitStartReturnsNotInitialized() {
        let (response, error) = waitForUntyped { completion in
            CloudCode.call("hello", completion: completion)
        }

        XCTAssertNil(response)
        XCTAssertEqual(error as? CloudCodeError, .notInitialized)
    }

    func testEndpointEncodesFunctionAndQueryAsURLComponents() {
        let endpoint = CloudCodeEndpoint(
            function: "hello world?",
            method: .post,
            query: ["source": "swift", "message": "hello world"],
            body: ["count": 2],
            headers: ["X-Trace": "test"]
        )

        XCTAssertEqual(endpoint.url, "/fn/hello%20world%3F?message=hello%20world&source=swift")
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.customHeader?["X-Trace"], "test")
        XCTAssertEqual(endpoint.payload as? [String: Int], ["count": 2])
    }

    func testEndpointPercentEncodesPlusInQueryValues() {
        let endpoint = CloudCodeEndpoint(
            function: "search",
            method: .get,
            query: ["email": "user+test@example.com"],
            body: nil,
            headers: nil
        )

        XCTAssertEqual(endpoint.url, "/fn/search?email=user%2Btest%40example.com")
    }

    func testHttpMethodsAreMappedToApiMethods() {
        XCTAssertEqual(CloudCodeHttpMethod.get.apiMethod, .get)
        XCTAssertEqual(CloudCodeHttpMethod.post.apiMethod, .post)
        XCTAssertEqual(CloudCodeHttpMethod.put.apiMethod, .put)
        XCTAssertEqual(CloudCodeHttpMethod.patch.apiMethod, .patch)
        XCTAssertEqual(CloudCodeHttpMethod.delete.apiMethod, .delete)
    }

    func testInvalidFunctionIsRejectedBeforeTransport() {
        let transport = TestCloudCodeTransport()
        let service = CloudCodeService(transport: transport)

        let (_, error) = waitForUntyped { completion in
            service.call(
                function: "invalid/function",
                method: .post,
                query: nil,
                body: nil,
                headers: nil,
                completion: completion
            )
        }

        guard case .invalidFunction(let function) = error as? CloudCodeError else {
            return XCTFail("Expected invalidFunction, got \(String(describing: error))")
        }
        XCTAssertEqual(function, "invalid/function")
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testFunctionSlugsRejectSpacesAndControlCharactersBeforeTransport() {
        for function in ["hello world", "hello\u{0000}world"] {
            let transport = TestCloudCodeTransport()
            let service = CloudCodeService(transport: transport)

            let (_, error) = waitForUntyped { completion in
                service.call(
                    function: function,
                    method: .get,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }

            XCTAssertEqual(error as? CloudCodeError, .invalidFunction(function))
            XCTAssertEqual(transport.requestCount, 0)
        }
    }

    func testInvalidBodyAndReservedHeadersAreRejectedBeforeTransport() {
        let transport = TestCloudCodeTransport()
        let service = CloudCodeService(transport: transport)

        let (_, bodyError) = waitForUntyped { completion in
            service.call(
                function: "hello",
                method: .post,
                query: nil,
                body: ["date": Date()],
                headers: nil,
                completion: completion
            )
        }
        XCTAssertEqual(bodyError as? CloudCodeError, .invalidBody)

        let (_, headerError) = waitForUntyped { completion in
            service.call(
                function: "hello",
                method: .post,
                query: nil,
                body: nil,
                headers: ["authorization": "spoofed"],
                completion: completion
            )
        }
        guard case .invalidHeader(let header) = headerError as? CloudCodeError else {
            return XCTFail("Expected invalidHeader, got \(String(describing: headerError))")
        }
        XCTAssertEqual(header, "authorization")
        XCTAssertEqual(transport.requestCount, 0)
    }

    func testTracingHeadersAreAcceptedAsBusinessHeaders() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{}".utf8),
            headers: [:],
            error: nil
        )
        let service = CloudCodeService(transport: transport)

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "traceable",
                method: .get,
                query: nil,
                body: nil,
                headers: [
                    "X-Trace-Id": "trace",
                    "traceparent": "parent",
                    "X-AppAmbit-Correlation": "correlation",
                    "X-Internal-Test": "internal"
                ],
                completion: completion
            )
        }

        XCTAssertNil(error)
        XCTAssertNotNil(response)
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testDefaultTimeoutIsSixtySecondsAndCustomRequestDataIsForwarded() {
        let transport = TestCloudCodeTransport()
        let service = CloudCodeService(transport: transport)

        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{\"ok\":true}".utf8),
            headers: [:],
            error: nil
        )

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "hello",
                method: .patch,
                query: ["source": "ios"],
                body: ["message": "hello"],
                headers: ["X-Trace": "test"],
                completion: completion
            )
        }

        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.data as? [String: Bool], ["ok": true])
        XCTAssertEqual(transport.lastTimeout, 60)
        XCTAssertEqual(transport.lastEndpoint?.method, .patch)
        XCTAssertEqual(transport.lastEndpoint?.url, "/fn/hello?source=ios")
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testAllJSONResultShapesAreSupported() {
        let payloads = [
            "{\"ok\":true}",
            "[1,\"two\",true]",
            "\"hello\"",
            "7",
            "true",
            "null"
        ]

        for payload in payloads {
            let transport = TestCloudCodeTransport()
            transport.response = CloudCodeTransportResponse(
                statusCode: 200,
                data: Data(payload.utf8),
                headers: [:],
                error: nil
            )
            let service = CloudCodeService(transport: transport)

            let (response, error) = waitForUntyped { completion in
                service.call(
                    function: "json-values",
                    method: .post,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }

            XCTAssertNil(error, payload)
            XCTAssertNotNil(response, payload)
            switch payload {
            case "\"hello\"": XCTAssertTrue(response?.data is String)
            case "7": XCTAssertTrue(response?.data is Int)
            case "true": XCTAssertTrue(response?.data is Bool)
            case "null": XCTAssertTrue(response?.data is NSNull)
            default: break
            }
        }
    }

    func testHTTPErrorBridgesStructuredMetadataToNSError() {
        let error = CloudCodeError.http(
            statusCode: 404,
            body: .object(["error": .string("not_found")]),
            rawBody: nil,
            requestId: "error-id"
        ) as NSError

        XCTAssertEqual(error.domain, CloudCodeError.errorDomain)
        XCTAssertEqual(error.code, 10)
        XCTAssertEqual(error.userInfo[CloudCodeErrorKeys.statusCode] as? Int, 404)
        XCTAssertEqual(
            (error.userInfo[CloudCodeErrorKeys.body] as? [String: Any])?["error"] as? String,
            "not_found"
        )
        XCTAssertEqual(error.userInfo[CloudCodeErrorKeys.requestId] as? String, "error-id")
    }

    func testEmptySuccessfulBodyMapsToNSNullForUntypedResponse() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: nil,
            headers: ["X-Request-Id": "empty-body-id"],
            error: nil
        )
        let service = CloudCodeService(transport: transport)

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "empty-body",
                method: .get,
                query: nil,
                body: nil,
                headers: nil,
                completion: completion
            )
        }

        XCTAssertNil(error)
        XCTAssertTrue(response?.data is NSNull)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.requestId, "empty-body-id")
    }

    func testTypedResultAndRequestIdFallbackArePreserved() {
        struct Greeting: Decodable, Equatable {
            let greeting: String
        }

        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 201,
            data: Data("{\"greeting\":\"hello\",\"request_id\":\"body-id\"}".utf8),
            headers: [:],
            error: nil
        )
        let service = CloudCodeService(transport: transport)

        let resultBox = ResultBox<CloudCodeResult<Greeting>, CloudCodeError>()
        let expectation = expectation(description: "typed result")
        service.call(
            function: "typed",
            method: .post,
            query: nil,
            body: nil,
            headers: nil,
            as: Greeting.self
        ) { result, error in
            resultBox.set(result, error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertNil(resultBox.error)
        XCTAssertEqual(resultBox.value?.data, Greeting(greeting: "hello"))
        XCTAssertEqual(resultBox.value?.statusCode, 201)
        XCTAssertEqual(resultBox.value?.requestId, "body-id")
    }

    func testTyped204CompletesWithoutDecodingError() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 204,
            data: nil,
            headers: ["X-Request-Id": "empty-id"],
            error: nil
        )
        let service = CloudCodeService(transport: transport)
        let expectation = expectation(description: "typed 204 result")
        let resultBox = ResultBox<CloudCodeResult<String>, CloudCodeError>()

        service.call(
            function: "empty",
            method: .delete,
            query: nil,
            body: nil,
            headers: nil,
            as: String.self
        ) { receivedResult, receivedError in
            resultBox.set(receivedResult, receivedError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertNil(resultBox.value?.data)
        XCTAssertEqual(resultBox.value?.statusCode, 204)
        XCTAssertEqual(resultBox.value?.requestId, "empty-id")
        XCTAssertEqual(resultBox.value?.headers["X-Request-Id"], "empty-id")
        XCTAssertNil(resultBox.error)
    }

    func testTypedEmptySuccessfulBodyCompletesWithNilDataAndMetadata() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: nil,
            headers: ["X-Request-Id": "empty-body-id"],
            error: nil
        )
        let service = CloudCodeService(transport: transport)
        let expectation = expectation(description: "typed empty result")
        let resultBox = ResultBox<CloudCodeResult<String>, CloudCodeError>()

        service.call(
            function: "empty-body",
            method: .get,
            query: nil,
            body: nil,
            headers: nil,
            as: String.self
        ) { receivedResult, receivedError in
            resultBox.set(receivedResult, receivedError)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertNil(resultBox.value?.data)
        XCTAssertEqual(resultBox.value?.statusCode, 200)
        XCTAssertEqual(resultBox.value?.requestId, "empty-body-id")
        XCTAssertEqual(resultBox.value?.headers["X-Request-Id"], "empty-body-id")
        XCTAssertNil(resultBox.error)
    }

    func testCallbacksAreDeliveredOnMainQueue() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{}".utf8),
            headers: [:],
            error: nil
        )
        let service = CloudCodeService(transport: transport)
        let validationExpectation = expectation(description: "validation callback on main")
        let transportExpectation = expectation(description: "transport callback on main")

        service.call(
            function: "invalid/function",
            method: .get,
            query: nil,
            body: nil,
            headers: nil
        ) { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            validationExpectation.fulfill()
        }

        service.call(
            function: "valid",
            method: .get,
            query: nil,
            body: nil,
            headers: nil
        ) { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            transportExpectation.fulfill()
        }

        wait(for: [validationExpectation, transportExpectation], timeout: 2)
    }

    func testTransportErrorsKeepTheirMeaning() {
        let cases: [(Error, CloudCodeError)] = [
            (URLError(.notConnectedToInternet), .networkUnavailable),
            (URLError(.networkConnectionLost), .networkUnavailable),
            (URLError(.timedOut), .timedOut),
            (ApiExceptions.invalidURL, .invalidURL)
        ]

        for (transportError, expectedError) in cases {
            let transport = TestCloudCodeTransport()
            transport.response = CloudCodeTransportResponse(
                statusCode: nil,
                data: nil,
                headers: [:],
                error: transportError
            )
            let service = CloudCodeService(transport: transport)
            let (_, error) = waitForUntyped { completion in
                service.call(
                    function: "transport-error",
                    method: .get,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }
            XCTAssertEqual(error as? CloudCodeError, expectedError)
        }
    }

    func testHeaderRequestIdTakesPriorityOverBodyRequestId() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{\"request_id\":\"body-id\"}".utf8),
            headers: ["x-request-id": "header-id"],
            error: nil
        )
        let service = CloudCodeService(transport: transport)

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "request-id",
                method: .get,
                query: nil,
                body: nil,
                headers: nil,
                completion: completion
            )
        }

        XCTAssertNil(error)
        XCTAssertEqual(response?.requestId, "header-id")
    }

    func testHTTPErrorsPreserveStatusBodyAndRequestId() {
        for statusCode in [400, 401, 402, 404, 429, 500, 503, 504] {
            let transport = TestCloudCodeTransport()
            transport.response = CloudCodeTransportResponse(
                statusCode: statusCode,
                data: Data("{\"error\":\"failed\",\"request_id\":\"error-id\"}".utf8),
                headers: [:],
                error: nil
            )
            let service = CloudCodeService(transport: transport)

            let (_, error) = waitForUntyped { completion in
                service.call(
                    function: "error",
                    method: .post,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }

            guard case .http(let actualStatus, let body, _, let requestId) = error as? CloudCodeError else {
                return XCTFail("Expected HTTP error for status \(statusCode), got \(String(describing: error))")
            }
            XCTAssertEqual(actualStatus, statusCode)
            XCTAssertEqual(body, .object(["error": .string("failed"), "request_id": .string("error-id")]))
            XCTAssertEqual(requestId, "error-id")
        }
    }

    func testHTTPErrorParsesOnlyObjectsAndArraysAndPreservesRawScalars() {
        let structuredBodies: [(String, JSONValue)] = [
            ("{\"error\":\"failed\"}", .object(["error": .string("failed")])),
            ("[\"failed\",1]", .array([.string("failed"), .int(1)]))
        ]

        for (rawBody, expectedBody) in structuredBodies {
            let transport = TestCloudCodeTransport()
            transport.response = CloudCodeTransportResponse(
                statusCode: 500,
                data: Data(rawBody.utf8),
                headers: [:],
                error: nil
            )
            let service = CloudCodeService(transport: transport)

            let (_, error) = waitForUntyped { completion in
                service.call(
                    function: "structured-error",
                    method: .get,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }

            guard case .http(_, let body, let rawBody, _) = error as? CloudCodeError else {
                return XCTFail("Expected structured HTTP error, got \(String(describing: error))")
            }
            XCTAssertEqual(body, expectedBody)
            XCTAssertNil(rawBody)
        }

        for rawBody in ["<html><body>gateway failure</body></html>", "\"failed\"", "42", "true", "null"] {
            let transport = TestCloudCodeTransport()
            transport.response = CloudCodeTransportResponse(
                statusCode: 500,
                data: Data(rawBody.utf8),
                headers: [:],
                error: nil
            )
            let service = CloudCodeService(transport: transport)

            let (_, error) = waitForUntyped { completion in
                service.call(
                    function: "raw-error",
                    method: .get,
                    query: nil,
                    body: nil,
                    headers: nil,
                    completion: completion
                )
            }

            guard case .http(_, let body, let preservedBody, _) = error as? CloudCodeError else {
                return XCTFail("Expected raw HTTP error, got \(String(describing: error))")
            }
            XCTAssertNil(body)
            XCTAssertEqual(preservedBody, rawBody)
        }
    }

    func testNoCallbackAfterCancellation() {
        let transport = TestCloudCodeTransport()
        let service = CloudCodeService(transport: transport)
        let callbackExpectation = expectation(description: "callback is suppressed")
        callbackExpectation.isInverted = true

        let token = service.call(
            function: "slow",
            method: .post,
            query: nil,
            body: nil,
            headers: nil
        ) { _, _ in
            callbackExpectation.fulfill()
        }

        transport.deliver(CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{\"ok\":true}".utf8),
            headers: [:],
            error: nil
        ))
        token.cancel()
        wait(for: [callbackExpectation], timeout: 0.2)
    }

    func testFacadeUsesInitializedCloudCodeService() {
        let transport = TestCloudCodeTransport()
        transport.response = CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{\"ok\":true}".utf8),
            headers: [:],
            error: nil
        )
        CloudCode.initialize(service: CloudCodeService(transport: transport))

        let (response, error) = waitForUntyped { completion in
            CloudCode.call("hello", completion: completion)
        }

        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(transport.requestCount, 1)
    }

    func testSharedTransportOmitsCloudCodeGETBodyAndPreservesDELETEBody() throws {
        let requestCapture = RequestCapture()
        TestURLProtocol.requestHandler = { request in
            requestCapture.append(request)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["X-Request-Id": "raw-id"]
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }
        defer { TestURLProtocol.reset() }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let apiService = AppAmbitApiService(
            storageService: InMemoryStorage(),
            urlSession: URLSession(configuration: configuration),
            isConnected: { true }
        )

        let getEndpoint = CloudCodeEndpoint(
            function: "get-function",
            method: .get,
            query: ["message": "hello world"],
            body: ["ignored": true],
            headers: ["X-Test": "get"]
        )
        getEndpoint.skipAuthorization = true
        let getResponse = waitForRawResponse(apiService, endpoint: getEndpoint)

        let deleteEndpoint = CloudCodeEndpoint(
            function: "delete-function",
            method: .delete,
            query: nil,
            body: ["keep": true],
            headers: ["X-Test": "delete"]
        )
        deleteEndpoint.skipAuthorization = true
        let deleteResponse = waitForRawResponse(apiService, endpoint: deleteEndpoint)

        XCTAssertEqual(getResponse.statusCode, 200)
        XCTAssertEqual(getResponse.headers["X-Request-Id"], "raw-id")
        XCTAssertEqual(deleteResponse.statusCode, 200)

        let requests = requestCapture.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0].httpMethod, "GET")
        XCTAssertTrue(try requestBodyData(from: requests[0])?.isEmpty ?? true)
        XCTAssertNil(requests[0].value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "X-Test"), "get")
        XCTAssertEqual(
            URLComponents(url: try XCTUnwrap(requests[0].url), resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "message", value: "hello world")]
        )

        XCTAssertEqual(requests[1].httpMethod, "DELETE")
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "X-Test"), "delete")
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: try XCTUnwrap(requestBodyData(from: requests[1]))) as? [String: Bool],
            ["keep": true]
        )
    }

    func testCloudCodeGatewayRefreshesAfter401AndRetriesOnce() throws {
        let requestCapture = RequestCapture()
        TestURLProtocol.requestHandler = { request in
            requestCapture.append(request)
            let path = request.url?.path ?? ""
            let cloudRequests = requestCapture.requests.filter { $0.url?.path.hasSuffix("/fn/retry") == true }
            let response: HTTPURLResponse
            let body: Data

            if path.hasSuffix("/consumer/token") {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"id\":123,\"token\":\"fresh-token\"}".utf8)
            } else if cloudRequests.count == 1 {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["X-Request-Id": "first-unauthorized"]
                )!
                body = Data("{\"error\":\"expired\"}".utf8)
            } else {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["X-Request-Id": "retried"]
                )!
                body = Data("{\"ok\":true}".utf8)
            }
            return (response, body)
        }
        defer { TestURLProtocol.reset() }

        let storage = InMemoryStorage()
        try storage.putAppId("test-app")
        try storage.putConsumerId("test-consumer")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let apiService = AppAmbitApiService(
            storageService: storage,
            urlSession: URLSession(configuration: configuration),
            isConnected: { true }
        )
        apiService.setToken("stale-token")
        let service = CloudCodeService(transport: apiService)

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "retry",
                method: .get,
                query: nil,
                body: nil,
                headers: nil,
                completion: completion
            )
        }

        let cloudRequests = requestCapture.requests.filter { $0.url?.path.hasSuffix("/fn/retry") == true }
        XCTAssertNil(error)
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.data as? [String: Bool], ["ok": true])
        XCTAssertEqual(cloudRequests.count, 2)
        XCTAssertEqual(
            cloudRequests[0].timeoutInterval,
            AppConstants.cloudCodeTimeout,
            accuracy: 0.1
        )
        XCTAssertEqual(cloudRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer stale-token")
        XCTAssertEqual(cloudRequests[1].value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/consumer/token") == true }.count, 1)
    }

    func testCloudCodeGatewayStopsAfterSecond401() throws {
        let requestCapture = RequestCapture()
        TestURLProtocol.requestHandler = { request in
            requestCapture.append(request)
            let response: HTTPURLResponse
            let body: Data
            if request.url?.path.hasSuffix("/consumer/token") == true {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"id\":123,\"token\":\"fresh-token\"}".utf8)
            } else {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: ["X-Request-Id": "still-unauthorized"]
                )!
                body = Data("{\"error\":\"unauthorized\"}".utf8)
            }
            return (response, body)
        }
        defer { TestURLProtocol.reset() }

        let storage = InMemoryStorage()
        try storage.putAppId("test-app")
        try storage.putConsumerId("test-consumer")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let apiService = AppAmbitApiService(
            storageService: storage,
            urlSession: URLSession(configuration: configuration),
            isConnected: { true }
        )
        apiService.setToken("stale-token")
        let service = CloudCodeService(transport: apiService)

        let (response, error) = waitForUntyped { completion in
            service.call(
                function: "retry-failure",
                method: .get,
                query: nil,
                body: nil,
                headers: nil,
                completion: completion
            )
        }

        let cloudRequests = requestCapture.requests.filter { $0.url?.path.hasSuffix("/fn/retry-failure") == true }
        guard case .http(let statusCode, _, _, let requestId) = error as? CloudCodeError else {
            return XCTFail("Expected second HTTP 401, got \(String(describing: error))")
        }
        XCTAssertNil(response)
        XCTAssertEqual(statusCode, 401)
        XCTAssertEqual(requestId, "still-unauthorized")
        XCTAssertEqual(cloudRequests.count, 2)
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/consumer/token") == true }.count, 1)
    }

    func testCloudCodeGatewayRetriesMutatingMethodsAfter401() throws {
        let requestCapture = RequestCapture()
        TestURLProtocol.requestHandler = { request in
            requestCapture.append(request)
            let response: HTTPURLResponse
            let body: Data
            if request.url?.path.hasSuffix("/consumer/token") == true {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"id\":123,\"token\":\"fresh-token\"}".utf8)
            } else {
                let requestCount = requestCapture.requests.filter { $0.url == request.url }.count
                if requestCount == 1 {
                    response = HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 401,
                        httpVersion: nil,
                        headerFields: ["X-Request-Id": "mutation-unauthorized"]
                    )!
                    body = Data("{\"error\":\"expired\"}".utf8)
                } else {
                    response = HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["X-Request-Id": "mutation-retried"]
                    )!
                    body = Data("{\"ok\":true}".utf8)
                }
            }
            return (response, body)
        }
        defer { TestURLProtocol.reset() }

        let storage = InMemoryStorage()
        try storage.putAppId("test-app")
        try storage.putConsumerId("test-consumer")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let apiService = AppAmbitApiService(
            storageService: storage,
            urlSession: URLSession(configuration: configuration),
            isConnected: { true }
        )
        apiService.setToken("stale-token")
        let service = CloudCodeService(transport: apiService)

        for (function, method) in [("post-mutation", CloudCodeHttpMethod.post),
                                    ("put-mutation", .put),
                                    ("delete-mutation", .delete)] {
            let (response, error) = waitForUntyped { completion in
                service.call(
                    function: function,
                    method: method,
                    query: nil,
                    body: ["value": true],
                    headers: nil,
                    completion: completion
                )
            }

            XCTAssertNil(error)
            XCTAssertEqual(response?.statusCode, 200)
            XCTAssertEqual(response?.data as? [String: Bool], ["ok": true])
        }

        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.contains("/fn/") == true }.count, 6)
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/consumer/token") == true }.count, 3)
    }

    func testConcurrentCloudCode401RequestsShareOneTokenRenewal() throws {
        let requestCapture = RequestCapture()
        let firstUnauthorizedResponses = DispatchSemaphore(value: 0)
        TestURLProtocol.requestHandler = { request in
            requestCapture.append(request)
            let path = request.url?.path ?? ""
            let pathRequests = requestCapture.requests.filter { $0.url?.path == path }
            let response: HTTPURLResponse
            let body: Data

            if path.hasSuffix("/consumer/token") {
                _ = firstUnauthorizedResponses.wait(timeout: .now() + 2)
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"id\":123,\"token\":\"shared-token\"}".utf8)
            } else if pathRequests.count == 1 {
                firstUnauthorizedResponses.signal()
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"error\":\"expired\"}".utf8)
            } else {
                response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                body = Data("{\"ok\":true}".utf8)
            }
            return (response, body)
        }
        defer { TestURLProtocol.reset() }

        let storage = InMemoryStorage()
        try storage.putAppId("test-app")
        try storage.putConsumerId("test-consumer")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let apiService = AppAmbitApiService(
            storageService: storage,
            urlSession: URLSession(configuration: configuration),
            isConnected: { true }
        )
        apiService.setToken("stale-token")
        let service = CloudCodeService(transport: apiService)
        let firstResult = ResultBox<CloudCodeResponse, Error>()
        let secondResult = ResultBox<CloudCodeResponse, Error>()
        let firstExpectation = expectation(description: "first concurrent result")
        let secondExpectation = expectation(description: "second concurrent result")

        DispatchQueue.global().async {
            service.call(
                function: "concurrent-one",
                method: .get,
                query: nil,
                body: nil,
                headers: nil
            ) { response, error in
                firstResult.set(response, error)
                firstExpectation.fulfill()
            }
        }
        DispatchQueue.global().async {
            service.call(
                function: "concurrent-two",
                method: .get,
                query: nil,
                body: nil,
                headers: nil
            ) { response, error in
                secondResult.set(response, error)
                secondExpectation.fulfill()
            }
        }

        wait(for: [firstExpectation, secondExpectation], timeout: 5)

        XCTAssertNil(firstResult.error)
        XCTAssertNil(secondResult.error)
        XCTAssertEqual(firstResult.value?.data as? [String: Bool], ["ok": true])
        XCTAssertEqual(secondResult.value?.data as? [String: Bool], ["ok": true])
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/consumer/token") == true }.count, 1)
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/fn/concurrent-one") == true }.count, 2)
        XCTAssertEqual(requestCapture.requests.filter { $0.url?.path.hasSuffix("/fn/concurrent-two") == true }.count, 2)
    }

    private func requestBodyData(from request: URLRequest) throws -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                data.append(buffer, count: count)
            } else if count == 0 {
                break
            } else {
                throw stream.streamError ?? NSError(domain: "CloudCodeTests", code: 1)
            }
        }
        return data
    }

    private func waitForRawResponse(_ apiService: AppAmbitApiService, endpoint: Endpoint) -> HTTPTransportResponse {
        let expectation = expectation(description: "raw response")
        let box = RawResponseBox()
        apiService.executeRawRequest(endpoint, timeout: 2) { response in
            box.set(response)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        return box.value!
    }

    private func waitForUntyped(
        _ start: (@escaping @Sendable (CloudCodeResponse?, Error?) -> Void) -> Void
    ) -> (CloudCodeResponse?, Error?) {
        let expectation = expectation(description: "Cloud Code response")
        let box = ResultBox<CloudCodeResponse, Error>()
        start { response, error in
            box.set(response, error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        return (box.value, box.error)
    }
}

private final class TestCloudCodeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingCompletion: (@Sendable (HTTPTransportResponse) -> Void)?

    var response: CloudCodeTransportResponse?
    private(set) var requestCount = 0
    private(set) var lastTimeout: TimeInterval?
    private(set) var lastEndpoint: Endpoint?

    func executeRawRequest(
        _ endpoint: Endpoint,
        timeout: TimeInterval,
        completion: @escaping @Sendable (HTTPTransportResponse) -> Void
    ) {
        lock.lock()
        requestCount += 1
        lastTimeout = timeout
        lastEndpoint = endpoint
        let response = response
        if response == nil {
            pendingCompletion = completion
        }
        lock.unlock()

        if let response {
            completion(response)
        }
    }

    func deliver(_ response: HTTPTransportResponse) {
        lock.lock()
        let completion = pendingCompletion
        pendingCompletion = nil
        lock.unlock()
        completion?(response)
    }
}

private final class ResultBox<Value, Failure: Error>: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value: Value?
    private(set) var error: Failure?

    func set(_ value: Value?, _ error: Failure?) {
        lock.lock()
        self.value = value
        self.error = error
        lock.unlock()
    }
}

private final class RequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }

    func append(_ request: URLRequest) {
        lock.lock()
        storedRequests.append(request)
        lock.unlock()
    }
}

private final class RawResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value: HTTPTransportResponse?

    func set(_ value: HTTPTransportResponse) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}
