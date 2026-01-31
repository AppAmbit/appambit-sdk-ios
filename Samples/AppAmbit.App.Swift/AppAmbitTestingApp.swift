import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct AppAmbitTestingApp: App {
    
    init() {
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
