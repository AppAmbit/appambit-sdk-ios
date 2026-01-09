import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "f0bdde14-fafc-4f2b-8a71-f0ffdf76bd03") {
            // Start Push SDK only after AppAmbit has finished initialization
            PushNotifications.start()
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
