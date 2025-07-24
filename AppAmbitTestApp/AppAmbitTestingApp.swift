import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        Analytics.enableManualSession()
        AppAmbit.start(appKey: "5034073e-1573-474e-b9a4-7bf7fa432ee5")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
