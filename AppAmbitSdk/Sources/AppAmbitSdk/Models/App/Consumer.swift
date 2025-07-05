struct Consumer: DictionaryConvertible {
    var appKey: String
    var deviceId: String
    var deviceModel: String
    var userId: String
    var userEmail: String
    var os: String
    var country: String
    var language: String
    
    func toDictionary() -> [String: Any] {
        return [
            "app_key": appKey,
            "device_id": deviceId,
            "device_model": deviceModel,
            "user_id": userId,
            "user_email": userEmail,
            "os": os,
            "country": country,
            "language": language
        ]
    }
}
