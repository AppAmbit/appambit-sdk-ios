import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        //Uncomment the line for manual session management
        //Analytics.enableManualSession()
        AppAmbit.start(appKey: "65ff1001-be3b-4d68-8dcf-8305907690a3")                
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
