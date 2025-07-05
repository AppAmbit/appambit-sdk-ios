import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        AppAmbit.start(appKey: "376dfb26-4cf0-4710-b7ec-5c2636439d18")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
