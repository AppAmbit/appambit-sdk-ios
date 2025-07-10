import SwiftUI
import AppAmbit;

@main
struct AppAmbitTestingApp: App {
    init() {
        AppAmbit.start(appKey: "17595189-fd4a-40dd-999f-e189d78f30fd")
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
