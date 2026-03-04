import XCTest
@testable import AppAmbit

final class RemoteConfigTests: XCTestCase {
    
    private var apiService: StubApiService!
    private var storageService: InMemoryStorage!
    
    override func setUp() {
        super.setUp()
        apiService = StubApiService()
        storageService = InMemoryStorage()
        RemoteConfig.initialize(apiService: apiService, storageService: storageService)
    }
    
    override func tearDown() {
        apiService = nil
        storageService = nil
        super.tearDown()
    }
    
    func testFetchFlow() {
        // Since we cannot reset static state (isEnable, isFetchCompleted), we test the flow in one go.
        // We assume isFetchCompleted starts as false (as no other tests call fetchAndStoreConfig).
        // we can't guarantee isEnable is false, so we enable it explicitly.
        
        RemoteConfig.enable()
        
        // 1. Test Failure (Network Error)
        // Given
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult<RemoteConfigResponse>(data: nil, errorType: .networkUnavailable))
        
        // When
        RemoteConfig.fetchAndStoreConfig()
        
        // Allow async API call to complete
        let expectationFail = XCTestExpectation(description: "wait for fetch failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectationFail.fulfill()
        }
        wait(for: [expectationFail], timeout: 2)
        
        // Then
        // Expect 1 call. Storage empty.
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 1)
        XCTAssertTrue(storageService.remoteConfigs.isEmpty)
        
        // 2. Test Success
        // Given
        let expectedConfigs: [String: RemoteConfigValue] = ["welcome_msg": .string("Hello")]
        let mockResponse = RemoteConfigResponse(configs: expectedConfigs)
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult(data: mockResponse, errorType: .none))
        
        // When
        RemoteConfig.fetchAndStoreConfig()
        
        // Allow async API call to complete
        let expectationSuccess = XCTestExpectation(description: "wait for fetch success")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectationSuccess.fulfill()
        }
        wait(for: [expectationSuccess], timeout: 2)
        
        // Then
        // Expect 2 calls total (1 fail + 1 success). Storage has data.
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 2)
        let storedValue = try? storageService.getConfig(key: "welcome_msg")
        XCTAssertNotNil(storedValue)
        XCTAssertEqual(storedValue?.value, "Hello")
        
        // 3. Test Caching (isFetchCompleted = true)
        // When calling again
        RemoteConfig.fetchAndStoreConfig()
        
        // Then
        // Expect NO new call (total remains 2).
        // Since isFetchCompleted is true, it returns early.
        // wait a bit just to be sure no async call happens?
        // Actually since it returns synchronously, call count shouldn't change.
        
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 2)
    }
    
    func testGetStringShouldReturnValueFromStorage() {
        // Given
        RemoteConfig.enable()
        let entity = RemoteConfigEntity(id: "1", key: "banner_text", value: "Welcome User")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getString("banner_text")
        
        // Then
        XCTAssertEqual(value, "Welcome User")
    }
    
    func testGetStringShouldReturnEmptyStringForMissingKey() {
        // Given
        RemoteConfig.enable()
        
        // When
        let value = RemoteConfig.getString("non_existent_key")
        
        // Then
        XCTAssertEqual(value, "")
    }
    
    func testGetLongShouldReturnParsedLongFromStorage() {
        // Given
        RemoteConfig.enable()
        let entity = RemoteConfigEntity(id: "1", key: "max_items", value: "10")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getLong("max_items")
        
        // Then
        XCTAssertEqual(value, 10)
    }
    
    func testGetDoubleShouldReturnParsedDoubleFromStorage() {
        // Given
        RemoteConfig.enable()
        let entity = RemoteConfigEntity(id: "1", key: "discount_rate", value: "0.5")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getDouble("discount_rate")
        
        // Then
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }
    
    func testGetBooleanShouldReturnParsedBooleanFromStorage() {
        // Given
        RemoteConfig.enable()
        let entity = RemoteConfigEntity(id: "1", key: "is_new_ui", value: "true")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getBoolean("is_new_ui")
        
        // Then
        XCTAssertTrue(value)
    }
}
