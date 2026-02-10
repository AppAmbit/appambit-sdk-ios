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
    
    func testFetchSuccessShouldStoreConfigsInMemoryAndReturnTrue() {
        // Given
        let expectedConfigs: [String: RemoteConfigValue] = ["welcome_msg": .string("Hello")]
        let mockResponse = RemoteConfigResponse(configs: expectedConfigs)
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult(data: mockResponse, errorType: .none))
        
        // When
        waitAsync { fulfill in
            RemoteConfig.fetch { success in
                XCTAssertTrue(success)
                fulfill()
            }
        }
        
        // Then
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 1)
    }
    
    func testFetchFailureShouldReturnFalse() {
        // Given
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult<RemoteConfigResponse>(data: nil, errorType: .networkUnavailable))
        
        // When
        waitAsync { fulfill in
            RemoteConfig.fetch { success in
                XCTAssertFalse(success)
                fulfill()
            }
        }
        
        // Then
        XCTAssertEqual(apiService.callCount(for: RemoteConfigEndpoint.self), 1)
    }
    
    func testActivateShouldPersistFetchedConfigsToStorage() {
        // Given
        let expectedConfigs: [String: RemoteConfigValue] = ["feature_enabled": .bool(true)]
        let mockResponse = RemoteConfigResponse(configs: expectedConfigs)
        apiService.stub(RemoteConfigEndpoint.self, result: ApiResult(data: mockResponse, errorType: .none))
        
        waitAsync { fulfill in
            RemoteConfig.fetch { _ in fulfill() }
        }
        
        // When
        let activated = RemoteConfig.activate()
        
        // Then
        XCTAssertTrue(activated)
        let storedValue = try? storageService.getConfig(key: "feature_enabled")
        XCTAssertNotNil(storedValue)
        XCTAssertEqual(storedValue?.value, "true")
    }
    
    func testGetStringShouldReturnValueFromStorage() {
        // Given
        let entity = RemoteConfigEntity(id: "1", key: "banner_text", value: "Welcome User")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getString("banner_text")
        
        // Then
        XCTAssertEqual(value, "Welcome User")
    }
    
    func testGetStringShouldFallbackToDefaultsIfStorageReturnsNull() {
        // Given - No storage value
        // We can't easily mock setDefaults(fromPlist:) without a real plist, 
        // let's use internal access to inject defaults or just assume it's empty and test fallback to ""
        
        // When
        let value = RemoteConfig.getString("non_existent_key")
        
        // Then
        XCTAssertEqual(value, "")
    }
    
    func testGetIntShouldReturnParsedIntegerFromStorage() {
        // Given
        let entity = RemoteConfigEntity(id: "1", key: "max_items", value: "10")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getInt("max_items")
        
        // Then
        XCTAssertEqual(value, 10)
    }
    
    func testGetDoubleShouldReturnParsedDoubleFromStorage() {
        // Given
        let entity = RemoteConfigEntity(id: "1", key: "discount_rate", value: "0.5")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getDouble("discount_rate")
        
        // Then
        XCTAssertEqual(value, 0.5, accuracy: 0.001)
    }
    
    func testGetBooleanShouldReturnParsedBooleanFromStorage() {
        // Given
        let entity = RemoteConfigEntity(id: "1", key: "is_new_ui", value: "true")
        try? storageService.putConfigs([entity])
        
        // When
        let value = RemoteConfig.getBoolean("is_new_ui")
        
        // Then
        XCTAssertTrue(value)
    }
}
