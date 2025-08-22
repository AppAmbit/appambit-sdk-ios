import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "46961e5f-5b11-4a3a-abca-b72a0382493e")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
