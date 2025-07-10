import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        AppAmbit.start(appKey: "7bba5bdc-0f0b-4770-8d59-1c4a62549311")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
