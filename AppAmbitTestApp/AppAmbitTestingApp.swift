import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "efa71f47-0b22-4a53-9692-7d0762a57e50")                
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
