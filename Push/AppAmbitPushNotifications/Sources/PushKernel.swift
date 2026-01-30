import Foundation
import UserNotifications
import UIKit

/// Core logic for APNs handling.
/// Decoupled from the main SDK for easy bridging to other platforms (e.g., .NET/MAUI).
@objc(PushKernel)
public class PushKernel: NSObject {
    private static let tag = "AppAmbitPushSDK"
    private nonisolated(unsafe) static var currentToken: String?
    private nonisolated(unsafe) static var isEnabled: Bool = false
    private nonisolated(unsafe) static var tokenListener: TokenListener?
    private nonisolated(unsafe) static var notificationCustomizer: NotificationCustomizer?
    
    // MARK: - Protocols
    
    @objc public protocol TokenListener: AnyObject {
        @objc func onNewToken(_ token: String)
    }
    
    @objc public protocol PermissionListener: AnyObject {
        @objc func onPermissionResult(_ granted: Bool)
    }
    
    @objc public protocol NotificationCustomizer: AnyObject {
        @objc func customizeNotification(_ notification: UNMutableNotificationContent, data: [String: Any])
    }
    
    // MARK: - Public API
    
    @objc public static func setNotificationsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        debugPrint("[\(tag)] Notifications enabled: \(enabled)")
        
        if !enabled {
            currentToken = nil
            debugPrint("[\(tag)] Token cleared as notifications were disabled.")
        }
    }
    
    @objc public static func isNotificationsEnabled() -> Bool {
        return isEnabled
    }
    
    @objc public static func getCurrentToken() -> String? {
        return currentToken
    }
    
    @objc public static func setTokenListener(_ listener: TokenListener?) {
        tokenListener = listener
    }
    
    @objc public static func setNotificationCustomizer(_ customizer: NotificationCustomizer?) {
        notificationCustomizer = customizer
    }
    
    /// Triggers the system notification permission request.
    @objc public static func requestNotificationPermission(listener: PermissionListener?) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                debugPrint("[\(tag)] Error requesting permissions: \(error.localizedDescription)")
            }
            
            debugPrint("[\(tag)] Permission granted: \(granted)")
            listener?.onPermissionResult(granted)
            
            if granted {
                setNotificationsEnabled(true)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    /// Processes a new APNs token and notifies the listener if it has changed.
    @objc public static func handleNewToken(_ token: String) {
        guard token != currentToken else {
            return
        }
        
        currentToken = token
        debugPrint("[\(tag)] New APNs Token: \(token)")
        
        tokenListener?.onNewToken(token)
    }
}
