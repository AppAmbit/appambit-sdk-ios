import Foundation

/// Notification model that encapsulates APNs push notification data
/// Aligned with the Android SDK model
public struct AppAmbitNotification {
    public let title: String?
    public let body: String?
    public let sound: String?
    public let badge: Int?
    public let category: String?
    public let threadId: String?
    public let interruptionLevel: String?
    public let imageUrl: String?
    public let data: [AnyHashable: Any]
    
    public init(title: String? = nil,
                body: String? = nil,
                sound: String? = nil,
                badge: Int? = nil,
                category: String? = nil,
                threadId: String? = nil,
                interruptionLevel: String? = nil,
                imageUrl: String? = nil,
                data: [AnyHashable: Any] = [:]) {
        self.title = title
        self.body = body
        self.sound = sound
        self.badge = badge
        self.category = category
        self.threadId = threadId
        self.interruptionLevel = interruptionLevel
        self.imageUrl = imageUrl
        self.data = data
    }
    
    /// Creates an AppAmbitNotification from APNs userInfo dictionary
    public static func from(userInfo: [AnyHashable: Any]) -> AppAmbitNotification {
        var title: String?
        var body: String?
        var sound: String?
        var badge: Int?
        var category: String?
        var threadId: String?
        var interruptionLevel: String?
        var imageUrl: String?
        var customData: [AnyHashable: Any] = [:]
        
        // Parse aps dictionary
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                title = alert["title"] as? String
                body = alert["body"] as? String
            } else if let alertString = aps["alert"] as? String {
                body = alertString
            }
            
            sound = parseSound(from: aps["sound"])
            badge = parseInt(from: aps["badge"])
            category = aps["category"] as? String
            threadId = aps["thread-id"] as? String
            interruptionLevel = parseString(from: aps["interruption-level"])
            imageUrl = parseString(from: aps["image"])
                ?? parseString(from: aps["image_url"])
                ?? parseString(from: aps["imageUrl"])
        }
        
        // Parse custom data (everything outside aps)
        for (key, value) in userInfo {
            if let keyString = key as? String, keyString != "aps" {
                customData[key] = value
            }
        }
        
        if imageUrl == nil {
            imageUrl = parseString(from: customData["image_url"])
                ?? parseString(from: customData["imageUrl"])
                ?? parseString(from: customData["image"])
        }
        
        return AppAmbitNotification(
            title: title,
            body: body,
            sound: sound,
            badge: badge,
            category: category,
            threadId: threadId,
            interruptionLevel: interruptionLevel,
            imageUrl: imageUrl,
            data: customData
        )
    }
    
    private static func parseSound(from value: Any?) -> String? {
        if let soundName = value as? String {
            return soundName
        }
        if let soundDict = value as? [String: Any] {
            return soundDict["name"] as? String
        }
        return nil
    }
    
    private static func parseInt(from value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.intValue
        }
        if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        }
        return nil
    }
    
    private static func parseString(from value: Any?) -> String? {
        if let stringValue = value as? String {
            return stringValue
        }
        if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        }
        return nil
    }
}
