import Foundation
import UserNotifications
import AppAmbitPushNotifications

final class SampleNotificationService: AppAmbitNotificationService {
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        // Copy original content to modify it before presenting to the user.
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            NSLog("[AppAmbitPushSDK] SampleNotificationService: Failed to create mutable content copy.")
            contentHandler(request.content)
            return
        }

        print("[AppAmbitPushSDK] SampleNotificationService: Processing notification -> %@", bestAttemptContent.title)

        // Extract custom payload data.
        let userInfo = bestAttemptContent.userInfo
        let dataPayload = userInfo["data"] as? [AnyHashable: Any] ?? userInfo

        bestAttemptContent.title += " Customs"
        
        // Set category for quick actions (e.g., "Reply", "Delete").
        if let category = dataPayload["category_type"] as? String {
            bestAttemptContent.categoryIdentifier = category
        }
        
        // Group notifications by thread (e.g., chat conversations).
        if let threadId = dataPayload["chat_id"] as? String {
            bestAttemptContent.threadIdentifier = threadId
        }
        
        // Interruption level: bypasses Focus if marked urgent (iOS 15+).
        if #available(iOS 15.0, *) {
            if let isUrgent = dataPayload["is_urgent"] as? String, isUrgent == "true" {
                bestAttemptContent.interruptionLevel = .timeSensitive
            }
        }
        
        // Update app badge.
        if let badgeCountString = dataPayload["badge_count"] as? String, let badgeCount = Int(badgeCountString) {
            bestAttemptContent.badge = NSNumber(value: badgeCount)
        }

        // Build a new request with modified content and delegate to the base class.
        // The base class handles image download (if imageUrl exists) and final delivery.
        let newRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: bestAttemptContent,
            trigger: request.trigger
        )
        
        NSLog("[AppAmbitPushSDK] SampleNotificationService: Content modified, delegating to parent handler.")
        super.didReceive(newRequest, withContentHandler: contentHandler)
    }

    override func handlePayload(_ notification: AppAmbitNotification, content: UNMutableNotificationContent) {
        NSLog("[AppAmbitPushSDK] SampleNotificationService: handlePayload — title: %@, body: %@",
              notification.title ?? "", notification.body ?? "")
    }

    override func serviceExtensionTimeWillExpire() {
        NSLog("[AppAmbitPushSDK] SampleNotificationService: Time limit reached — delivering best attempt content.")
        super.serviceExtensionTimeWillExpire()
    }
}
