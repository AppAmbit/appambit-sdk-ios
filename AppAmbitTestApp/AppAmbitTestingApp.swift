import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        Core.start(appKey: "382d34e3-40d7-49d1-b9ac-d834d4823c45")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
