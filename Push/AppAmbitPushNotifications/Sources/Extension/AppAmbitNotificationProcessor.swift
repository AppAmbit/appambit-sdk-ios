import UserNotifications

/// ObjC-callable processor. Use from a `UNNotificationServiceExtension` subclass when
/// subclasing `AppAmbitNotificationService` is not possible (e.g. ObjC extensions).
@objc(AppAmbitNotificationProcessor)
@objcMembers
public final class AppAmbitNotificationProcessor: NSObject {

    @objc(processRequest:contentHandler:handlePayload:)
    public static func process(
        request: UNNotificationRequest,
        contentHandler: @escaping (UNNotificationContent) -> Void,
        handlePayload: ((AppAmbitNotification, UNMutableNotificationContent) -> Void)? = nil
    ) {
        PushLogger.log("Service Extension triggered.")

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        let notification = AppAmbitNotification.from(userInfo: content.userInfo)
        handlePayload?(notification, content)
        attachImageIfNeeded(notification, content: content, contentHandler: contentHandler)
    }

    private static func attachImageIfNeeded(_ notification: AppAmbitNotification,
                                            content: UNMutableNotificationContent,
                                            contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let imageUrl = notification.imageUrl, !imageUrl.isEmpty else {
            contentHandler(content)
            return
        }

        PushNotificationAttachments.loadImageAttachment(from: imageUrl) { attachment in
            if let attachment {
                content.attachments = [attachment]
            }
            contentHandler(content)
        }
    }
}
