import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct AppAmbitTestingApp: App {
    @UIApplicationDelegateAdaptor(AppAmbitAppDelegate.self) var appDelegate
    
    init() {
        RemoteConfig.enable()
        
        // Push starts immediately so the swizzler is ready before network calls.
        // TokenListenerImpl waits internally until AppAmbit.isInitialized() == true.
        PushNotifications.start(debugMode: true)
        
        // Unified listener: handles foreground, opened, and background states.
        PushNotifications.setNotificationListener { userInfo, state in
            switch state {
            case .foreground:
                print("[Foreground] Notification received while app is open: \(userInfo)")
            case .opened:
                print("[Opened] User tapped the notification: \(userInfo)")
            case .background:
                print("[Background] Notification received in background: \(userInfo)")
            @unknown default:
                break
            }
        }        
        
        AppAmbit.start(appKey: "<YOUR-APPKEY>")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

