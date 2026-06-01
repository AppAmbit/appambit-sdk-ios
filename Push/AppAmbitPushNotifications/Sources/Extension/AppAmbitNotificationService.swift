import UserNotifications

/// Base class for the AppAmbit Notification Service Extension.
///
/// Subclass this from your NSE target to enable rich notifications. The base
/// class downloads any image referenced by the push payload (`image` key) and
/// attaches it to the notification before delivery.
///
/// Override `handlePayload(_:content:)` to mutate notification content
/// (title, body, badge, threadIdentifier, etc.) before delivery.
open class AppAmbitNotificationService: UNNotificationServiceExtension {
    private static let tag = "[AppAmbitPushSDK]"

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    open override func didReceive(_ request: UNNotificationRequest,
                                  withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let notification = AppAmbitNotification.from(userInfo: content.userInfo)
        handlePayload(notification, content: content)
        attachImageIfNeeded(notification, content: content, contentHandler: contentHandler)
    }

    open override func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }

    /// Hook for subclasses to mutate `content` before delivery. Default: no-op.
    open func handlePayload(_ notification: AppAmbitNotification,
                            content: UNMutableNotificationContent) {
        // Subclasses can mutate content here before delivery.
    }

    private func attachImageIfNeeded(_ notification: AppAmbitNotification,
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
