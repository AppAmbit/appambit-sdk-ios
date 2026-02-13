import Foundation

@objcMembers
public final class RemoteConfig: NSObject, @unchecked Sendable {
    
    private var apiService: ApiService?
    private var storageService: StorageService?
    
    private override init() { super.init() }
    public static let shared = RemoteConfig()
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }
    
    private nonisolated(unsafe) static var isEnable = false
    private nonisolated(unsafe) static var isFetchCompleted = false
    
    @objc
    public static func enable() {
        isEnable = true
    }
    
    static func fetchAndStoreConfig() {
        if !isEnable || isFetchCompleted {
            return
        }
        
        guard let apiService = shared.apiService,
              let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            AppAmbitLogger.log(message: "RemoteConfig: No initialized services")
            return
        }
        
        let endpoint = RemoteConfigEndpoint(appVersion: appVersion)
        
        apiService.executeRequest(endpoint, responseType: RemoteConfigResponse.self) { result in
            if let response = result.data {
                if let newConfigs = response.configs {
                    let entities = newConfigs.map { (key, value) in
                        let stringValue = String(describing: value.value)
                        return RemoteConfigEntity(id: UUID().uuidString, key: key, value: stringValue)
                    }
                    RemoteConfig.isFetchCompleted = true
                    try? shared.storageService?.putConfigs(entities)
                }
            } else {
                AppAmbitLogger.log(message: "RemoteConfig: Fetch failed: \(result.errorType)")
            }
        }
    }
    
    @objc
    public static func getString(_ key: String) -> String {
        let value = getValue(key)
        if let stringValue = value as? String {
            return stringValue
        }
        return value != nil ? String(describing: value!) : ""
    }
    
    @objc
    public static func getBoolean(_ key: String) -> Bool {
        let value = getValue(key)
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let stringValue = value as? String {
            if let boolValue = Bool(stringValue) {
                return boolValue
            }
            return (stringValue as NSString).boolValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }
        return false
    }
    
    @objc
    public static func getInt(_ key: String) -> Int {
        let value = getValue(key)
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue) ?? 0
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        return 0
    }
    
    @objc
    public static func getDouble(_ key: String) -> Double {
        let value = getValue(key)
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let stringValue = value as? String {
            return Double(stringValue) ?? 0.0
        }
        if let numberValue = value as? NSNumber {
            return numberValue.doubleValue
        }
        return 0.0
    }
    
    private static func getValue(_ key: String) -> Any? {
        guard RemoteConfig.isEnable else { return nil }
        
        if let storageService = shared.storageService,
           let config = try? storageService.getConfig(key: key) {
            return config.value
        }
        return nil
    }
}
