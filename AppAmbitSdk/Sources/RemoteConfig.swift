import Foundation

@objcMembers
public final class RemoteConfig: NSObject, @unchecked Sendable {
    
    private var apiService: ApiService?
    private var storageService: StorageService?
    
    private var remoteConfigs: [String: RemoteConfigValue] = [:]
    private var defaults: [String: Any] = [:]
    
    private override init() { super.init() }
    public static let shared = RemoteConfig()
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }
    
    @objc
    public static func setDefaults(fromPlist fileName: String) {
        shared.setDefaults(fromPlist: fileName)
    }
    
    private func setDefaults(fromPlist fileName: String) {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("AppAmbit: Failed to load defaults from plist: \(fileName)")
            return
        }
        self.defaults = dict
    }
    
    @objc
    public static func fetch(completion: (@Sendable (Bool) -> Void)? = nil) {
        shared.fetch(completion: completion)
    }
    
    private func fetch(completion: (@Sendable (Bool) -> Void)? = nil) {
        guard let apiService = apiService,
              let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            completion?(false)
            return
        }
        
        let endpoint = RemoteConfigEndpoint(appVersion: appVersion)
        
        apiService.executeRequest(endpoint, responseType: RemoteConfigResponse.self) { [weak self] result in
            if let response = result.data {
                if let newConfigs = response.configs {
                    self?.remoteConfigs = newConfigs
                    completion?(true)
                } else {
                    completion?(false)
                }
            } else {
                print("AppAmbit: Remote Config fetch failed: \(result.errorType)")
                completion?(false)
            }
        }
    }
    
    @objc
    public static func activate() -> Bool {
        return shared.activate()
    }
    
    private func activate() -> Bool {
        guard !remoteConfigs.isEmpty else { return false }
        
        let entities = remoteConfigs.map { (key, value) in
            let stringValue = String(describing: value.value)
             return RemoteConfigEntity(id: UUID().uuidString, key: key, value: stringValue)
        }
        
        do {
            try storageService?.putConfigs(entities)
            remoteConfigs.removeAll()
            return true
        } catch {
            print("AppAmbit: Failed to activate remote configs: \(error)")
            return false
        }
    }
    
    @objc
    public static func fetchAndActivate(completion: (@Sendable (Bool) -> Void)? = nil) {
        shared.fetchAndActivate(completion: completion)
    }
    
    private func fetchAndActivate(completion: (@Sendable (Bool) -> Void)? = nil) {
        fetch { [weak self] success in
            guard let self = self else { return }
            if success {
                let activated = self.activate()
                completion?(activated)
            } else {
                completion?(false)
            }
        }
    }
    
    @objc
    public static func getBoolean(_ key: String) -> Bool {
        return shared.getBoolean(key)
    }
    
    private func getBoolean(_ key: String) -> Bool {
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
        return shared.getInt(key)
    }
    
    private func getInt(_ key: String) -> Int {
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
        return shared.getDouble(key)
    }
    
    private func getDouble(_ key: String) -> Double {
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
    
    @objc
    public static func getString(_ key: String) -> String {
        return shared.getString(key)
    }
    
    private func getString(_ key: String) -> String {
        let value = getValue(key)
        if let stringValue = value as? String {
            return stringValue
        }
        return String(describing: value)
    }
    
    @objc
    public static func getValue(_ key: String) -> Any {
        return shared.getValue(key)
    }
    
    private func getValue(_ key: String) -> Any {
        if let config = try? storageService?.getConfig(key: key) {
            return config.value
        }
        if let defaultValue = defaults[key] {
            return defaultValue
        }
        return ""
    }
}
