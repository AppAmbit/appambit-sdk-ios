import Foundation
import UserNotifications
import UIKit

/// Internal class responsible for initializing push registration and delegates.
@objc(AppAmbitPushRegistration)
internal class AppAmbitPushRegistration: NSObject {
    
    @objc static func setup() {
        PushLogger.log("Initializing Push registration...")
        UNUserNotificationCenter.current().delegate = AppAmbitNotificationCenterDelegate.shared
        AppDelegateSwizzler.swizzleAppDelegateMethods()
    }
}

/// Handles notification center events (foreground, taps).
private class AppAmbitNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = AppAmbitNotificationCenterDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        PushLogger.log("Notification received in foreground.")
        PushKernel.notifyNotificationReceived(userInfo: userInfo, state: .foreground)

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        PushLogger.log("Notification opened by user.")
        PushKernel.notifyNotificationReceived(userInfo: userInfo, state: .opened)
        completionHandler()
    }
}
