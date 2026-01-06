import Foundation
import UserNotifications

/// PushNotifications - Public API for push notifications
/// Esta es la fachada que expone funcionalidad de push notifications
public class PushNotifications {
    private static let tag = "AppAmbitPushSDK"
    
    // MARK: - Type Aliases
    
    public typealias PermissionListener = (Bool) -> Void
    
    // MARK: - Initialization
    
    /// Starts the Push Notifications SDK
    /// - Parameters:
    ///   - debugMode: Enables detailed logging
    ///   - autoRequestPermissions: Automatically requests permissions on start
    public static func start(debugMode: Bool = false, autoRequestPermissions: Bool = false) {
        print("[\(tag)] Starting Push SDK.")
        
        // Set up token listener
        PushKernel.setTokenListener(TokenListenerImpl())
        
        // Start the kernel
        PushKernel.start()
        
        if autoRequestPermissions {
            requestNotificationPermission(listener: nil)
        }
    }
    
    // MARK: - Notification Settings
    
    /// Enables or disables push notifications
    public static func setNotificationsEnabled(_ enabled: Bool) {
        print("[\(tag)] Setting notifications enabled state to: \(enabled)")
        PushKernel.setNotificationsEnabled(enabled)
    }
    
    /// Checks if notifications are enabled
    public static func isNotificationsEnabled() -> Bool {
        return PushKernel.isNotificationsEnabled()
    }
    
    /// Requests notification permissions from the user
    public static func requestNotificationPermission(listener: PermissionListener?) {
        PushKernel.requestNotificationPermission(listener: listener != nil ? PermissionListenerWrapper(listener: listener!) : nil)
    }
    
    // MARK: - Testing (DEBUG Only)
    
    #if DEBUG
    /// Simulates a push notification for testing in simulator
    /// Only available in DEBUG builds
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Message body
    ///   - data: Custom data dictionary (optional)
    public static func simulateNotification(title: String, body: String, data: [String: Any]? = nil) {
        print("[\(tag)] Simulating notification for testing...")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if let data = data {
            content.userInfo = data
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[\(tag)] Error simulating notification: \(error)")
            } else {
                print("[\(tag)] Notification simulated successfully")
            }
        }
    }
    #endif
}

// MARK: - Internal Listener Implementations

private class TokenListenerImpl: PushKernel.TokenListener {
    func onNewToken(_ token: String) {
        DispatchQueue.main.async {
            if PushKernel.isNotificationsEnabled() {
                print("[AppAmbitPushSDK] APNs token received and notifications are enabled.")
                // TODO: Sync with backend when ConsumerService is available
            } else {
                print("[AppAmbitPushSDK] APNs token received, but notifications are disabled by the user.")
            }
        }
    }
}

private class PermissionListenerWrapper: PushKernel.PermissionListener {
    private let listener: PushNotifications.PermissionListener
    
    init(listener: @escaping PushNotifications.PermissionListener) {
        self.listener = listener
    }
    
    func onPermissionResult(_ granted: Bool) {
        listener(granted)
    }
}
