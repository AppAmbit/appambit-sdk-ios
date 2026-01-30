import UserNotifications

/// Base class for the Notification Service Extension.
/// Handles background processing of notifications (e.g., downloading images) before they are displayed.
open class AppAmbitNotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    open override func didReceive(_ request: UNNotificationRequest,
                                   withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        debugPrint("[AppAmbitPushSDK] Notification Service Extension triggered.")
        
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            debugPrint("[AppAmbitPushSDK] Failed to create mutable copy of notification content.")
            contentHandler(request.content)
            return
        }

        bestAttemptContent = content
        let notification = AppAmbitNotification.from(userInfo: content.userInfo)
        
        if let imageUrl = notification.imageUrl {
            debugPrint("[AppAmbitPushSDK] Notification image URL found: \(imageUrl)")
        }
        
        handlePayload(notification, userInfo: content.userInfo)
        attachImageIfNeeded(notification, content: content, contentHandler: contentHandler)
    }

    open override func serviceExtensionTimeWillExpire() {
        // Time is up, display whatever we have processed so far
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }

    /// Override this method to perform custom payload inspection or modification.
    open func handlePayload(_ notification: AppAmbitNotification, userInfo: [AnyHashable: Any]) {
        // Subclasses can implement custom logic here
    }

    /// Downloads and attaches the notification image if a URL is present.
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
