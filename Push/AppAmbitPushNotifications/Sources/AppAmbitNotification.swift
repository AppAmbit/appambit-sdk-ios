import Foundation

/// Represents an AppAmbit notification payload.
/// Parses the raw APNs dictionary into a structured model.
public struct AppAmbitNotification {
    public let title: String?
    public let subtitle: String?
    public let body: String?
    public let imageUrl: String?
    public let data: [AnyHashable: Any]
    
    /// Creates an AppAmbitNotification from an APNs userInfo dictionary.
    public static func from(userInfo: [AnyHashable: Any]) -> AppAmbitNotification {
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]
        
        let title = alert?["title"] as? String
        let subtitle = alert?["subtitle"] as? String
        let body = alert?["body"] as? String
        
        // Support multiple common keys for the image URL
        let imageUrl = userInfo["image"] as? String ?? 
                     userInfo["image_url"] as? String ?? 
                     userInfo["imageUrl"] as? String ??
                     alert?["launch-image"] as? String
        
        return AppAmbitNotification(
            title: title,
            subtitle: subtitle,
            body: body,
            imageUrl: imageUrl,
            data: userInfo
        )
    }
}
