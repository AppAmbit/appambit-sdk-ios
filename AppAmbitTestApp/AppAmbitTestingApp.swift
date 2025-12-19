import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "<YOUR-APPKEY>")
        
        // Start Push Notifications without requesting permissions automatically
        PushNotifications.start(
            debugMode: true,
            autoRequestPermissions: false  // Permissions requested via button
        )
        
        // Register for remote notifications (APNs)
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // MARK: - APNs Token Handling
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token (Hex): \(tokenString)")
        print("Token Length: \(tokenString.count) characters")
        print("Raw Token Data: \(deviceToken as NSData)")
        PushKernel.handleNewToken(tokenString)
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - Main App
@main
struct AppAmbitTestingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
