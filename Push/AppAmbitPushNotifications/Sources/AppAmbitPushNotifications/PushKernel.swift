import Foundation
import UserNotifications
import UIKit

/// PushKernel - Decoupled core for APNs handling
/// No tiene dependencias del Core SDK de AppAmbit
/// Puede ser usado directamente por bridges (.NET/MAUI)
public class PushKernel {
    private static let tag = "AppAmbitPushSDK"
    private nonisolated(unsafe) static var currentToken: String?
    private nonisolated(unsafe) static var isEnabled: Bool = false
    private nonisolated(unsafe) static var tokenListener: TokenListener?
    private nonisolated(unsafe) static var notificationCustomizer: NotificationCustomizer?
    
    // MARK: - Protocols
    
    public protocol TokenListener: AnyObject {
        func onNewToken(_ token: String)
    }
    
    public protocol PermissionListener {
        func onPermissionResult(_ granted: Bool)
    }
    
    public protocol NotificationCustomizer: AnyObject {
        func customizeNotification(_ notification: UNMutableNotificationContent, data: [String: Any])
    }
    
    // MARK: - Public Methods
    
    public static func start() {
        print("[\(tag)] Initializing Push Kernel...")
        
        // Configure UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        
        print("[\(tag)] Push Kernel initialized successfully.")
    }
    
    public static func setNotificationsEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("[\(tag)] Notifications enabled: \(enabled)")
        
        if !enabled {
            currentToken = nil
            print("[\(tag)] Token cleared due to notifications being disabled.")
        }
    }
    
    public static func isNotificationsEnabled() -> Bool {
        return isEnabled
    }
    
    public static func getCurrentToken() -> String? {
        return currentToken
    }
    
    public static func setTokenListener(_ listener: TokenListener?) {
        tokenListener = listener
    }
    
    public static func setNotificationCustomizer(_ customizer: NotificationCustomizer?) {
        notificationCustomizer = customizer
    }
    
    public static func requestNotificationPermission(listener: PermissionListener?) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[\(tag)] Error requesting notification permission: \(error.localizedDescription)")
            }
            
            print("[\(tag)] Notification permission granted: \(granted)")
            listener?.onPermissionResult(granted)
            
            if granted {
                setNotificationsEnabled(true)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    public static func handleNewToken(_ token: String) {
        guard token != currentToken else {
            print("[\(tag)] Token unchanged, skipping update.")
            return
        }
        
        currentToken = token
        print("[\(tag)] New APNs Token received: \(token)")
        print("[\(tag)] Token length: \(token.count) characters")
        
        tokenListener?.onNewToken(token)
    }
    
    // MARK: - Internal Delegate
    
    private class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
        nonisolated(unsafe) static let shared = NotificationCenterDelegate()
        
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                   willPresent notification: UNNotification,
                                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            print("[\(tag)] Notification received in foreground")
            
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
        
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                   didReceive response: UNNotificationResponse,
                                   withCompletionHandler completionHandler: @escaping () -> Void) {
            print("[\(tag)] Notification tapped by user")
            completionHandler()
        }
    }
}
