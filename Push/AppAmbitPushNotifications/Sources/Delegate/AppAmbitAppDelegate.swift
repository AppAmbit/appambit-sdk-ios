import UIKit
import UserNotifications

/// Preconfigured AppDelegate for SwiftUI applications.
open class AppAmbitAppDelegate: NSObject, UIApplicationDelegate {
    
    @objc dynamic open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Swizzler intercepts this call
    }
    
    @objc dynamic open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Swizzler intercepts this call
    }
    
    @objc dynamic open func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Swizzler intercepts this call
        completionHandler(.newData)
    }
}
