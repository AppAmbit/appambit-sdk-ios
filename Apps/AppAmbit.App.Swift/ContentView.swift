import SwiftUI

struct ContentView: View {
    @AppStorage("tab-view-customization")
    private var customization: TabViewCustomization

    var body: some View {
        TabView {
            CrashesView()
                .tabItem {
                    Label("Crashes", systemImage: "exclamationmark.triangle")
                }

            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }

            LoadView()
                .tabItem {
                    Label("Load", systemImage: "bolt.horizontal.circle")
                }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
        .ignoresSafeArea(.keyboard)
    }
}
