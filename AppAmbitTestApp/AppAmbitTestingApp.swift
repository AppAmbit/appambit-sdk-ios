import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "bcb0438a-6db7-4260-8305-b1547b8f9c26")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
