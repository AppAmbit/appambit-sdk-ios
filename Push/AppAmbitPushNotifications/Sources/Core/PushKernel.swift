import Foundation
import UserNotifications
import UIKit

/// Core engine for APNs handling.
/// Decoupled from the public facade for platform bridging.
@objc(PushKernel)
public class PushKernel: NSObject {
    
    private nonisolated(unsafe) static var currentToken: String?
    private nonisolated(unsafe) static var isEnabled: Bool = UserDefaults.standard.bool(forKey: "com.appambit.push.enabled")
    private nonisolated(unsafe) static var tokenListener: TokenListener?
    private nonisolated(unsafe) static var lastKnownPermission: Bool = UserDefaults.standard.bool(forKey: "com.appambit.push.permission")
    private nonisolated(unsafe) static var notificationListener: (([AnyHashable: Any], PushNotificationState) -> Void)?
    /// Notifications that arrived (typically as cold-start taps) before any
    /// listener was registered. Replayed when `setNotificationListener` runs.
    private nonisolated(unsafe) static var pendingNotifications: [(userInfo: [AnyHashable: Any], state: PushNotificationState)] = []

    // MARK: - Protocols
    
    @objc public protocol TokenListener: AnyObject {
        @objc func onNewToken(_ token: String)
    }
    
    @objc public protocol PermissionListener: AnyObject {
        @objc func onPermissionResult(_ granted: Bool)
    }

    // MARK: - Setup
    
    @objc public static func setupSwizzling() {
        AppAmbitPushRegistration.setup()
        PushLogger.log("SetupSwizzling called. Initial isEnabled: \(isEnabled)")

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let grantStatus = (status == .authorized || status == .provisional)
            if lastKnownPermission != grantStatus {
                lastKnownPermission = grantStatus
                UserDefaults.standard.set(grantStatus, forKey: "com.appambit.push.permission")
            }
            if grantStatus && !isEnabled {
                PushLogger.log("System permission detected. Enabling SDK state.")
                setNotificationsEnabled(true)
            }
        }
    }

    @objc public static func setDebugMode(_ enabled: Bool) {
        PushLogger.debugMode = enabled
    }
    
    // MARK: - Token
    
    @objc public static func getCurrentToken() -> String? {
        return currentToken
    }
    
    @objc public static func setTokenListener(_ listener: TokenListener?) {
        tokenListener = listener
    }
    
    @objc public static func handleNewToken(_ token: String) {
        if token == currentToken { return }
        currentToken = token
        PushLogger.log("New APNs token received: \(token)")
        tokenListener?.onNewToken(token)
    }

    // MARK: - Notifications Enabled
    
    @objc public static func setNotificationsEnabled(_ enabled: Bool) {
        isEnabled = enabled

        UserDefaults.standard.set(enabled, forKey: "com.appambit.push.enabled")
        UserDefaults.standard.synchronize()
        PushLogger.log("Notifications enabled: \(enabled)")
    }
    
    @objc public static func isNotificationsEnabled() -> Bool {
        return isEnabled
    }

    // MARK: - Permissions
    
    @objc public static func hasNotificationPermission() -> Bool {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            if status != lastKnownPermission {
                lastKnownPermission = status
                UserDefaults.standard.set(status, forKey: "com.appambit.push.permission")
            }
        }
        return lastKnownPermission
    }

    @objc public static func requestNotificationPermission(listener: PermissionListener?) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                PushLogger.error("Permission request error: \(error.localizedDescription)")
            }
            PushLogger.log("Permission granted: \(granted)")
            listener?.onPermissionResult(granted)
            if granted {
                setNotificationsEnabled(true)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    // MARK: - Listeners

    @objc public static func setNotificationListener(_ listener: @escaping ([AnyHashable: Any], PushNotificationState) -> Void) {
        notificationListener = listener
        // Drain any notifications that arrived before the listener was set
        // (typically a cold-start tap that fired the UN delegate while the
        // Flutter engine / Dart isolate was still bootstrapping).
        let drained = pendingNotifications
        pendingNotifications = []
        for item in drained {
            listener(item.userInfo, item.state)
        }
    }

    // MARK: - Internal Dispatch

    internal static func notifyNotificationReceived(userInfo: [AnyHashable: Any], state: PushNotificationState) {
        PushLogger.log("Notification dispatched -> state: \(state == .foreground ? "foreground" : "opened")")
        if let listener = notificationListener {
            listener(userInfo, state)
        } else {
            pendingNotifications.append((userInfo, state))
        }
    }
}
