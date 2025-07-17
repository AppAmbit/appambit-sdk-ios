struct Consumer: DictionaryConvertible {
    var appKey: String
    var deviceId: String
    var deviceModel: String
    var userId: String
    var userEmail: String?
    var os: String
    var country: String
    var language: String
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "app_key": appKey,
            "device_id": deviceId,
            "device_model": deviceModel,
            "user_id": userId,
            "os": os,
            "country": country,
            "language": language
        ]

        if let email = userEmail {
            dict["user_email"] = email
        }

        return dict
    }
}
