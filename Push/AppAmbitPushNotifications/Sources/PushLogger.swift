import Foundation

/// Internal logger for the AppAmbit Push Notification SDK.
/// Handles debug and error logging in a professional format without emojis.
public class PushLogger {
    
    /// Global flag to control debug logging verbosity.
    /// Can be toggled via PushNotifications.start(debugMode: true).
    public nonisolated(unsafe) static var debugMode = false
    
    private static let tag = "[AppAmbitPushSDK]"
    
    /// Logs a debug message if debugMode is enabled.
    /// - Parameter message: The message to log.
    public static func log(_ message: String) {
        if debugMode {
            print("\(tag) \(message)")
        }
    }
    
    /// Logs a critical error or important information that should always be visible.
    /// - Parameter message: The error message.
    public static func error(_ message: String) {
        print("\(tag) \(message)")
    }
    
    /// Logs a raw message, useful for large payloads or formatted text.
    public static func raw(_ message: String) {
        if debugMode {
            print(message)
        }
    }
}
