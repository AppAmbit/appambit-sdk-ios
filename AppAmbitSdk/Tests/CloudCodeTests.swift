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
        XCTAssertNil(resultBox.value)
        XCTAssertNil(resultBox.error)
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

        token.cancel()
        transport.deliver(CloudCodeTransportResponse(
            statusCode: 200,
            data: Data("{\"ok\":true}".utf8),
            headers: [:],
            error: nil
        ))
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

private final class TestCloudCodeTransport: CloudCodeTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingCompletion: (@Sendable (CloudCodeTransportResponse) -> Void)?

    var response: CloudCodeTransportResponse?
    private(set) var requestCount = 0
    private(set) var lastTimeout: TimeInterval?
    private(set) var lastEndpoint: CloudCodeEndpoint?

    func executeCloudCodeRequest(
        _ endpoint: CloudCodeEndpoint,
        timeout: TimeInterval,
        completion: @escaping @Sendable (CloudCodeTransportResponse) -> Void
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

    func deliver(_ response: CloudCodeTransportResponse) {
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
