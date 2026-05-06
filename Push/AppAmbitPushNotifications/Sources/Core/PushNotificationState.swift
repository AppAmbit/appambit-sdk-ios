import Foundation

/// Indicates the context in which a notification was received.
@objc public enum PushNotificationState: Int {
    /// The app was in the foreground when the notification arrived.
    case foreground
    /// The user tapped the notification to open the app.
    case opened
}
