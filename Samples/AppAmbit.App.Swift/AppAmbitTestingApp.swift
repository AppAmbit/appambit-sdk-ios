import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct AppAmbitTestingApp: App {
    
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        //RemoteConfig.disable()
        AppAmbit.start(appKey: "<YOUR-APPKEY>") {
            PushNotifications.start(debugMode: true)
          }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
