import Foundation

/// Notification model that encapsulates APNs push notification data
public struct AppAmbitNotification {
    public let title: String?
    public let body: String?
    public let badge: Int?
    public let sound: String?
    public let data: [String: Any]
    
    public init(title: String? = nil,
                body: String? = nil,
                badge: Int? = nil,
                sound: String? = nil,
                data: [String: Any] = [:]) {
        self.title = title
        self.body = body
        self.badge = badge
        self.sound = sound
        self.data = data
    }
    
    /// Crea un AppAmbitNotification desde el userInfo de APNs
    public static func from(userInfo: [AnyHashable: Any]) -> AppAmbitNotification {
        var title: String?
        var body: String?
        var badge: Int?
        var sound: String?
        var customData: [String: Any] = [:]
        
        // Parse aps dictionary
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                title = alert["title"] as? String
                body = alert["body"] as? String
            } else if let alertString = aps["alert"] as? String {
                body = alertString
            }
            
            badge = aps["badge"] as? Int
            sound = aps["sound"] as? String
        }
        
        // Parse custom data (everything outside aps)
        for (key, value) in userInfo {
            if let keyString = key as? String, keyString != "aps" {
                customData[keyString] = value
            }
        }
        
        return AppAmbitNotification(
            title: title,
            body: body,
            badge: badge,
            sound: sound,
            data: customData
        )
    }
}
