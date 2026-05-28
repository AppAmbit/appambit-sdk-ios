import UIKit
import UserNotifications

/// Preconfigured AppDelegate for SwiftUI applications.
open class AppAmbitAppDelegate: NSObject, UIApplicationDelegate {

    @objc dynamic open func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushLogger.log("AppDelegate received APNs token directly: \(tokenString)")
        PushKernel.handleNewToken(tokenString)
    }

    @objc dynamic open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushLogger.error("AppDelegate registration failure: \(error.localizedDescription)")
    }
}
