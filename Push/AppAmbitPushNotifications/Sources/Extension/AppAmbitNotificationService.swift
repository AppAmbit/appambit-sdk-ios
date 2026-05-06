import UserNotifications

/// Base class for the Notification Service Extension.
open class AppAmbitNotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    open override func didReceive(_ request: UNNotificationRequest,
                                   withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        PushLogger.log("Service Extension triggered.")

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        bestAttemptContent = content

        let notification = AppAmbitNotification.from(userInfo: content.userInfo)

        handlePayload(notification, userInfo: content.userInfo)
        attachImageIfNeeded(notification, content: content, contentHandler: contentHandler)
    }

    open override func serviceExtensionTimeWillExpire() {
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }

    open func handlePayload(_ notification: AppAmbitNotification, userInfo: [AnyHashable: Any]) {
        // Subclasses can implement custom logic here
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
