import XCTest
@testable import AppAmbit

final class ConsumerServiceTests: XCTestCase {
    private var api: StubApiService!
    private var storage: InMemoryStorage!
    private var service: ConsumerService!

    override func setUp() {
        super.setUp()
        api = StubApiService()
        storage = InMemoryStorage()
        service = ConsumerService(
            apiService: api,
            appInfoService: ServiceContainer.shared.appInfoService,
            storageService: storage
        )
    }

    override func tearDown() {
        service = nil
        storage = nil
        api = nil
        super.tearDown()
    }

    func testUpdateConsumer_UsesStoredValuesWhenCalledForResync() throws {
        try storage.putConsumerId("consumer-123")
        try storage.putDeviceToken("stored-token")
        try storage.putPushEnabled(false)
        api.stub(UpdateConsumerEndpoint.self, result: ApiResult<VoidResponse>.success(VoidResponse()))

        let success = waitForUpdate(deviceToken: nil, pushEnabled: nil)

        XCTAssertTrue(success)
        XCTAssertEqual(api.callCount(for: UpdateConsumerEndpoint.self), 1)
        XCTAssertEqual(try storage.getDeviceToken(), "")
        XCTAssertFalse(try storage.getPushEnabled())

        let endpoint: UpdateConsumerEndpoint? = api.lastEndpoint(for: UpdateConsumerEndpoint.self)
        XCTAssertNotNil(endpoint)
        let payload = endpoint?.payload as? UpdateConsumer
        XCTAssertNotNil(payload)
        XCTAssertNil(payload?.deviceToken)
        XCTAssertEqual(payload?.pushEnabled, false)
    }

    func testUpdateConsumer_PersistsIncomingValuesAndSendsThemToEndpoint() throws {
        try storage.putConsumerId("consumer-456")
        api.stub(UpdateConsumerEndpoint.self, result: ApiResult<VoidResponse>.success(VoidResponse()))

        let success = waitForUpdate(deviceToken: "fresh-token", pushEnabled: true)

        XCTAssertTrue(success)
        XCTAssertEqual(api.callCount(for: UpdateConsumerEndpoint.self), 1)
        XCTAssertEqual(try storage.getDeviceToken(), "fresh-token")
        XCTAssertTrue(try storage.getPushEnabled())

        let endpoint: UpdateConsumerEndpoint? = api.lastEndpoint(for: UpdateConsumerEndpoint.self)
        let payload = endpoint?.payload as? UpdateConsumer
        XCTAssertEqual(payload?.deviceToken, "fresh-token")
        XCTAssertEqual(payload?.pushEnabled, true)
    }

    func testUpdateConsumer_SkipsRequestWhenConsumerIdIsMissing() throws {
        let success = waitForUpdate(deviceToken: "fresh-token", pushEnabled: true)

        XCTAssertFalse(success)
        XCTAssertEqual(api.callCount(for: UpdateConsumerEndpoint.self), 0)
        XCTAssertEqual(try storage.getDeviceToken(), "fresh-token")
        XCTAssertTrue(try storage.getPushEnabled())
    }

    func testUpdateConsumer_DoesNotSendEnabledTrueWithoutToken() throws {
        try storage.putConsumerId("consumer-789")

        let success = waitForUpdate(deviceToken: nil, pushEnabled: true)

        XCTAssertFalse(success)
        XCTAssertEqual(api.callCount(for: UpdateConsumerEndpoint.self), 0)
        XCTAssertEqual(try storage.getDeviceToken(), "")
        XCTAssertTrue(try storage.getPushEnabled())
    }

    private func waitForUpdate(deviceToken: String?, pushEnabled: Bool?) -> Bool {
        let expectation = expectation(description: "wait for consumer update")
        var result = false

        service.updateConsumer(deviceToken: deviceToken, pushEnabled: pushEnabled) { success in
            result = success
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        return result
    }
}