import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "27b05155-a179-4d56-932e-925e6d15dbe1")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
