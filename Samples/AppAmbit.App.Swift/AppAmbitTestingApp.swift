import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "<YOUR-APPKEY>")                
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
