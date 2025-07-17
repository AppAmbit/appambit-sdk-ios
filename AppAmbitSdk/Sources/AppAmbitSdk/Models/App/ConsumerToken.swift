struct ConsumerToken: DictionaryConvertible {
    var appKey: String
    var consumerId: String
    
    init(appKey: String, consumerId: String) {
        self.appKey = appKey
        self.consumerId = consumerId
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "app_key": appKey,
            "consumer_id": consumerId
        ]
        
    }
}
