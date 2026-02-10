import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "<YOUR-APPKEY>") {
            PushNotifications.start()
            RemoteConfig.setDefaults(fromPlist: "default_values")
            RemoteConfig.fetchAndActivate { success in
                if(success) {
                    debugPrint("Fetched data successfully")
                }else {
                    debugPrint("Failed to fetch data")
                }
            }
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
