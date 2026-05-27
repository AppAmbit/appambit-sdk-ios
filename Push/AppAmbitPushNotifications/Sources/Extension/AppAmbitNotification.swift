import Foundation

/// Represents an AppAmbit notification payload.
@objc(AppAmbitNotification)
@objcMembers
public final class AppAmbitNotification: NSObject {
    public let title: String?
    public let body: String?
    public let imageUrl: String?
    public let data: [AnyHashable: Any]

    public init(title: String?, body: String?, imageUrl: String?, data: [AnyHashable: Any]) {
        self.title = title
        self.body = body
        self.imageUrl = imageUrl
        self.data = data
        super.init()
    }

    public static func from(userInfo: [AnyHashable: Any]) -> AppAmbitNotification {
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]

        let title = alert?["title"] as? String
        let body = alert?["body"] as? String

        let imageUrl = userInfo["image"] as? String

        var data = userInfo
        data.removeValue(forKey: "image")

        return AppAmbitNotification(
            title: title,
            body: body,
            imageUrl: imageUrl,
            data: data
        )
    }
}
