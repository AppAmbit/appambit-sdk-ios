import Foundation
import UserNotifications

/// Helper for handling notification attachments, such as rich images.
public enum PushNotificationAttachments {
    
    /// Downloads an image from a URL and converts it into a UNNotificationAttachment.
    public static func loadImageAttachment(from urlString: String,
                                           completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempUrl, _, error in
            guard let tempUrl, error == nil else {
                debugPrint("[AppAmbitPushSDK] Download error: \(error?.localizedDescription ?? "Invalid URL")")
                completion(nil)
                return
            }

            let ext = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
            let localUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                // Move the temporary file to a permanent location for iOS to use
                try FileManager.default.moveItem(at: tempUrl, to: localUrl)
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: localUrl,
                    options: nil
                )
                completion(attachment)
            } catch {
                debugPrint("[AppAmbitPushSDK] Attachment creation failed: \(error.localizedDescription)")
                completion(nil)
            }
        }

        task.resume()
    }

    /// Convenience method to load an attachment from an AppAmbitNotification model.
    public static func loadImageAttachment(for notification: AppAmbitNotification,
                                           completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let urlString = notification.imageUrl, !urlString.isEmpty else {
            completion(nil)
            return
        }

        loadImageAttachment(from: urlString, completion: completion)
    }
}
