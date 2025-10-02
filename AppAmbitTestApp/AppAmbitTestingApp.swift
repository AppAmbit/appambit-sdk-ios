import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "3f9c8cba-1628-40b4-93ae-6dbba53210c3")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}
