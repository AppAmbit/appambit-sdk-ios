import Foundation
import UserNotifications
import UIKit

/// Internal class responsible for initializing push registration and delegates.
@objc(AppAmbitPushRegistration)
internal class AppAmbitPushRegistration: NSObject {
    
    /// Initializes delegates and triggers swizzling.
    @objc static func setup() {
        PushLogger.log("Initializing Push registration...")
        
        // Setup the shared notification center delegate
        UNUserNotificationCenter.current().delegate = AppAmbitNotificationCenterDelegate.shared
        
        // Activate AppDelegate swizzling for automatic token capture
        AppDelegateSwizzler.swizzleAppDelegateMethods()
        
        PushLogger.log("Push registration setup complete.")
    }
}

/// Handles notification center events (foreground, background, and taps).
private class AppAmbitNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = AppAmbitNotificationCenterDelegate()
    
    /// Triggered when a notification is received while the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        if PushLogger.debugMode {
            let userInfo = notification.request.content.userInfo
            PushLogger.log("Notification received in foreground.")
            PushLogger.raw("Payload: \(userInfo)")
        }
        
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    /// Triggered when the user interacts with (taps) a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        PushLogger.log("User interacted with notification.")
        completionHandler()
    }
}
