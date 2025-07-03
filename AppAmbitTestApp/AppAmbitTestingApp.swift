import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        AppAmbit.start()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
