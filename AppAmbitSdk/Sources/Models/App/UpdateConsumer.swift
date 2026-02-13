struct UpdateConsumer: DictionaryConvertible {
    var deviceToken: String?
    var pushEnabled: Bool
    
    init(deviceToken: String?, pushEnabled: Bool) {
        self.deviceToken = deviceToken
        self.pushEnabled = pushEnabled
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "push_enabled": pushEnabled
        ]
        
        if let token = deviceToken {
            dict["device_token"] = token
        }
        
        return dict
    }
}
