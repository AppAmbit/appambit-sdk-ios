import Foundation
import UserNotifications
import AppAmbit

/// Public facade for managing AppAmbit Push Notifications.
/// This is the primary entry point for developers.
@objc(PushNotifications)
public class PushNotifications: NSObject {
    
    // MARK: - Type Aliases
    
    public typealias PermissionListener = (Bool) -> Void
    
    // MARK: - Initialization
    
    /// Starts the Push Notification SDK.
    /// - Parameters:
    ///   - debugMode: If true, enables detailed console logging.
    ///   - autoRequestPermissions: If true, automatically requests system permissions on startup.
    public static func start(debugMode: Bool = false, autoRequestPermissions: Bool = false) {
        // Configure Logger first
        PushLogger.debugMode = debugMode
        PushLogger.log("Starting Push SDK...")
        
        // Setup internal token handler
        PushKernel.setTokenListener(TokenListenerImpl())
        
        // Setup registration and swizzling
        AppAmbitPushRegistration.setup()
        
        if autoRequestPermissions {
            requestNotificationPermission(listener: nil)
        }
    }
    
    /// Convenience initializer for Objective-C callers.
    @objc(start)
    public static func startObjC() {
        start()
    }
    
    // MARK: - Notification Configuration
    
    /// Globally enables or disables notifications in the internal state.
    /// Globally enables or disables notifications in the internal state.
    public static func setNotificationsEnabled(_ enabled: Bool) {
        PushLogger.log("Setting notifications enabled to: \(enabled)")
        PushKernel.setNotificationsEnabled(enabled)
    }
    
    /// Returns whether notifications are currently enabled in the SDK state.
    @objc
    public static func isNotificationsEnabled() -> Bool {
        return PushKernel.isNotificationsEnabled()
    }
    
    /// Requests system notification permissions from the user.
    public static func requestNotificationPermission(listener: PermissionListener?) {
        PushKernel.requestNotificationPermission(listener: listener != nil ? PermissionListenerWrapper(listener: listener!) : nil)
    }

    /// Objective-C bridge for requestNotificationPermission.
    @objc(requestNotificationPermissionWithListener:)
    public static func requestNotificationPermissionObjC(listener: ((Bool)->Void)?) {
        requestNotificationPermission(listener: listener)
    }

    /// Allows customization of notification appearance before display.
    @objc(setNotificationCustomizer:)
    public static func setNotificationCustomizer(_ customizer: Any?) {
        PushLogger.log("setNotificationCustomizer called (pending Swift implementation).")
    }
}

// MARK: - Internal Support

/// Listener responsible for syncing the APNs token with the AppAmbit backend.
private class TokenListenerImpl: PushKernel.TokenListener {
    func onNewToken(_ token: String) {
        DispatchQueue.main.async {
            if PushKernel.isNotificationsEnabled() {
                PushLogger.log("Syncing token with backend...")
                ConsumerService.shared.updateConsumer(deviceToken: token, pushEnabled: true) { success in
                    if success {
                        PushLogger.log("Token synced successfully.")
                    } else {
                        PushLogger.error("Failed to sync token.")
                    }
                }
            } else {
                PushLogger.log("Token received but notifications are disabled.")
            }
        }
    }
}

/// Wrapper to bridge public API closures with kernel protocols.
private class PermissionListenerWrapper: PushKernel.PermissionListener {
    private let listener: PushNotifications.PermissionListener
    
    init(listener: @escaping PushNotifications.PermissionListener) {
        self.listener = listener
    }
    
    func onPermissionResult(_ granted: Bool) {
        listener(granted)
    }
}
