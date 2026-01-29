import Foundation
import UserNotifications

public enum PushNotificationAttachments {
    public static func loadImageAttachment(from urlString: String,
                                           completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempUrl, _, error in
            guard let tempUrl, error == nil else {
                completion(nil)
                return
            }

            let ext = url.pathExtension.isEmpty ? "tmp" : url.pathExtension
            let localUrl = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            do {
                try FileManager.default.moveItem(at: tempUrl, to: localUrl)
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: localUrl,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }

        task.resume()
    }

    public static func loadImageAttachment(for notification: AppAmbitNotification,
                                           completion: @escaping (UNNotificationAttachment?) -> Void) {
        guard let urlString = notification.imageUrl, !urlString.isEmpty else {
            completion(nil)
            return
        }

        loadImageAttachment(from: urlString, completion: completion)
    }
}
