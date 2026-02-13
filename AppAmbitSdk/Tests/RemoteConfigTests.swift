import XCTest
@testable import AppAmbit

final class RemoteConfigTests: XCTestCase {
    
    private var apiService: StubApiService!
    private var storageService: InMemoryStorage!
    
    override func setUp() {
        super.setUp()
        apiService = StubApiService()
        storageService = InMemoryStorage()
        RemoteConfig.resetForTesting()
        RemoteConfig.initialize(apiService: apiService, storageService: storageService)
    }
    
    override func tearDown() {
        RemoteConfig.resetForTesting()
        apiService = nil
        storageService = nil
        super.tearDown()
    }
    
    func testFetchAndStoreConfigShouldStoreConfigsWhenEnabled() {
        // Given
        let expectedConfigs: [String: RemoteConfigValue] = ["welcome_msg": .string("Hello")]
        let mockResponse = RemoteConfigResponse(configs: expectedConfigs)
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult(data: mockResponse, errorType: .none))
        
        RemoteConfig.setEnable()
        
        // When
        RemoteConfig.fetchAndStoreConfig()
        
        // Allow async API call to complete
        let expectation = XCTestExpectation(description: "wait for fetch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        
        // Then
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 1)
        let storedValue = try? storageService.getConfig(key: "welcome_msg")
        XCTAssertNotNil(storedValue)
        XCTAssertEqual(storedValue?.value, "Hello")
    }
    
    func testFetchFailureShouldNotStoreConfigs() {
        // Given
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult<RemoteConfigResponse>(data: nil, errorType: .networkUnavailable))
        
        RemoteConfig.setEnable()
        
        // When
        RemoteConfig.fetchAndStoreConfig()
        
        // Allow async API call to complete
        let expectation = XCTestExpectation(description: "wait for fetch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        
        // Then
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 1)
        XCTAssertTrue(storageService.remoteConfigs.isEmpty)
    }
    
    func testFetchShouldNotCallApiWhenNotEnabled() {
        // Given
        let mockResponse = RemoteConfigResponse(configs: ["key": .string("value")])
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult(data: mockResponse, errorType: .none))
        
        // When - do NOT call setEnable()
        RemoteConfig.fetchAndStoreConfig()
        
        // Allow time for potential async call
        let expectation = XCTestExpectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
        
        // Then - API should never be called
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 0)
    }
    
    func testGetStringShouldReturnValueFromStorage() {
        // Given
        RemoteConfig.setEnable()
        let entity = RemoteConfigEntity(id: "1", key: "banner_text", value: "Welcome User")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getString("banner_text")
        
        // Then
        XCTAssertEqual(value, "Welcome User")
    }
    
    func testGetStringShouldReturnEmptyStringForMissingKey() {
        // Given
        RemoteConfig.setEnable()
        
        // When
        let value = RemoteConfig.getString("non_existent_key")
        
        // Then
        XCTAssertEqual(value, "")
    }
    
    func testGetIntShouldReturnParsedIntegerFromStorage() {
        // Given
        RemoteConfig.setEnable()
        let entity = RemoteConfigEntity(id: "1", key: "max_items", value: "10")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getInt("max_items")
        
        // Then
        XCTAssertEqual(value, 10)
    }
    
    func testGetDoubleShouldReturnParsedDoubleFromStorage() {
        // Given
        RemoteConfig.setEnable()
        let entity = RemoteConfigEntity(id: "1", key: "discount_rate", value: "0.5")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getDouble("discount_rate")
        
        // Then
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }
    
    func testGetBooleanShouldReturnParsedBooleanFromStorage() {
        // Given
        RemoteConfig.setEnable()
        let entity = RemoteConfigEntity(id: "1", key: "is_new_ui", value: "true")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getBoolean("is_new_ui")
        
        // Then
        XCTAssertTrue(value)
    }
}
