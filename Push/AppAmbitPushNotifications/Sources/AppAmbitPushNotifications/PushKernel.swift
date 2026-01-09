import Foundation
import UserNotifications
import UIKit

/// PushKernel - Decoupled core for APNs handling
/// No dependencies on AppAmbit Core SDK
/// Can be used directly by bridges (.NET/MAUI)
final class PushKernel {
    private static let tag = "AppAmbitPushKernel"
    private static let prefsName = "com.appambit.sdk.push.prefs"
    private static let notificationsEnabledKey = "notifications_enabled"
    private nonisolated(unsafe) static var currentToken: String?
    private nonisolated(unsafe) static var tokenListener: TokenListener?
    private nonisolated(unsafe) static var isStarted = false
    private nonisolated(unsafe) static var notificationCustomizer: PushNotifications.NotificationCustomizer?
    
    // MARK: - Protocols
    
    protocol TokenListener: AnyObject {
        func onNewToken(_ token: String)
    }
    
    protocol PermissionListener: Sendable {
        func onPermissionResult(_ granted: Bool)
    }
    
    // MARK: - Internal Methods (Called by PushNotifications facade)
    
    static func start() {
        if isStarted {
            debugPrint("[\(tag)] PushKernel already started.")
            return
        }
        
        debugPrint("[\(tag)] PushKernel started successfully.")
        isStarted = true
        
        // Setup automatic APNs token interception
        APNsTokenInterceptor.setup()
        
        // Configure UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        
        // If notifications are enabled, register for remote notifications
        if isNotificationsEnabled() {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            // Send current token to listener if available
            if let token = currentToken, !token.isEmpty {
                debugPrint("[\(tag)] Current APNs Token: \(token)")
                debugPrint("[\(tag)] Notifying listener of existing token on start.")
                tokenListener?.onNewToken(token)
            } else {
                debugPrint("[\(tag)] No token available yet.")
            }
        } else {
            debugPrint("[\(tag)] Notifications are disabled by user. Skipping token fetch.")
        }
    }
    
    static func setNotificationsEnabled(_ enabled: Bool) {
        debugPrint("[\(tag)] Setting notifications enabled status to: \(enabled)")
        getPrefs().set(enabled, forKey: notificationsEnabledKey)
        getPrefs().synchronize()
        
        if enabled {
            DispatchQueue.main.async {
                debugPrint("[\(tag)] Registering for remote notifications.")
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            currentToken = nil
            DispatchQueue.main.async {
                UIApplication.shared.unregisterForRemoteNotifications()
            }
        }
    }
    
    static func isNotificationsEnabled() -> Bool {
        // Default to true if not explicitly set by the user
        if getPrefs().object(forKey: notificationsEnabledKey) == nil {
            return true
        }
        return getPrefs().bool(forKey: notificationsEnabledKey)
    }
    
    static func getCurrentToken() -> String? {
        return currentToken
    }
    
    static func setTokenListener(_ listener: TokenListener?) {
        tokenListener = listener
    }
    
    static func setNotificationCustomizer(_ customizer: PushNotifications.NotificationCustomizer?) {
        notificationCustomizer = customizer
    }
    
    static func requestNotificationPermission(listener: PermissionListener?) {
        APNsTokenInterceptor.setup()
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                debugPrint("[\(tag)] Error requesting notification permission: \(error.localizedDescription)")
            }
            
            debugPrint("[\(tag)] Notification permission granted: \(granted)")
            DispatchQueue.main.async {
                listener?.onPermissionResult(granted)
            }
            
            if granted {
                setNotificationsEnabled(true)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    static func handleNewToken(_ token: String) {
        let isSame = (token == currentToken)
        currentToken = token
        if isSame {
            debugPrint("[\(tag)] APNs token unchanged; notifying listener anyway.")
        } else {
            debugPrint("[\(tag)] New APNs Token received: \(token)")
            debugPrint("[\(tag)] Token length: \(token.count) characters")
        }
        tokenListener?.onNewToken(token)
    }
    
    // MARK: - Private Helpers
    
    private static func debugPrintPayload(_ userInfo: [AnyHashable: Any], context: String) {
        #if DEBUG
        let json = jsonString(from: userInfo)
        print("[\(tag)] Push payload (\(context)): \(json)")
        #endif
    }

    private static func applyNotificationFields(_ notification: AppAmbitNotification,
                                                to content: UNMutableNotificationContent) {
        if let title = notification.title, !title.isEmpty {
            content.title = title
        }
        if let body = notification.body, !body.isEmpty {
            content.body = body
        }
        if let badge = notification.badge, content.badge == nil {
            content.badge = NSNumber(value: badge)
        }
        if let category = notification.category, content.categoryIdentifier.isEmpty {
            content.categoryIdentifier = category
        }
        if let threadId = notification.threadId, content.threadIdentifier.isEmpty {
            content.threadIdentifier = threadId
        }
        if let soundName = notification.sound, content.sound == nil {
            if soundName.lowercased() == "default" {
                content.sound = .default
            } else {
                content.sound = .init(named: UNNotificationSoundName(rawValue: soundName))
            }
        }
        if #available(iOS 15.0, *),
           let level = notification.interruptionLevel,
           let mapped = mapInterruptionLevel(level) {
            content.interruptionLevel = mapped
        }
    }

    @available(iOS 15.0, *)
    private static func mapInterruptionLevel(_ value: String) -> UNNotificationInterruptionLevel? {
        switch value.lowercased() {
        case "passive":
            return .passive
        case "active":
            return .active
        case "time-sensitive", "time_sensitive", "timesensitive":
            return .timeSensitive
        case "critical":
            return .critical
        default:
            return nil
        }
    }

    private static func jsonString(from userInfo: [AnyHashable: Any]) -> String {
        var sanitized: [String: Any] = [:]
        for (key, value) in userInfo {
            if let keyString = key as? String {
                sanitized[keyString] = value
            } else {
                sanitized[String(describing: key)] = value
            }
        }

        if JSONSerialization.isValidJSONObject(sanitized),
           let data = try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            return json
        }

        return String(describing: userInfo)
    }

    private static func getPrefs() -> UserDefaults {
        return UserDefaults.standard
    }
    
    // MARK: - Internal Delegate
    
    private class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
        static let shared = NotificationCenterDelegate()
        
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                   willPresent notification: UNNotification,
                                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            debugPrint("[\(tag)] Notification received in foreground")
            
            let userInfo = notification.request.content.userInfo
            PushKernel.debugPrintPayload(userInfo, context: "foreground")
            let appAmbitNotification = AppAmbitNotification.from(userInfo: userInfo)
            
            // Create mutable content for customization
            let content = notification.request.content.mutableCopy() as! UNMutableNotificationContent
            PushKernel.applyNotificationFields(appAmbitNotification, to: content)
            
            // Invoke customizer if set (before showing the notification)
            if let customizer = PushKernel.notificationCustomizer {
                debugPrint("[\(tag)] Invoking notification customizer")
                customizer(content, appAmbitNotification)
            }

            // Show the notification with (possibly) customized content
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
        
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                   didReceive response: UNNotificationResponse,
                                   withCompletionHandler completionHandler: @escaping () -> Void) {
            debugPrint("[\(tag)] Notification tapped by user")
            let userInfo = response.notification.request.content.userInfo
            PushKernel.debugPrintPayload(userInfo, context: "tap")
            completionHandler()
        }
    }
}
