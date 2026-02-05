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
    @objc
    public static func setNotificationsEnabled(_ enabled: Bool) {
        PushLogger.log("Setting notifications enabled to: \(enabled)")
        PushKernel.setNotificationsEnabled(enabled)
        
        let token = PushKernel.getCurrentToken()
        // Sync with backend
        ConsumerService.shared.updateConsumer(deviceToken: token, pushEnabled: enabled)
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

    /// Returns whether the system has granted notification permissions.
    @objc
    public static func hasNotificationPermission() -> Bool {
        return PushKernel.hasNotificationPermission()
    }

    /// Allows listening and customization of notifications before display.
    /// This is the professional way to intercept both local and remote notifications.
    public static func setNotificationCustomizer(_ listener: ((UNNotification) -> Void)?) {
        PushLogger.log("Notification customizer/listener registered.")
        PushKernel.setNotificationListener(listener)
    }

    /// Objective-C bridge for setNotificationCustomizer.
    @objc(setNotificationCustomizer:)
    public static func setNotificationCustomizerObjC(_ listener: ((UNNotification) -> Void)?) {
        setNotificationCustomizer(listener)
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
