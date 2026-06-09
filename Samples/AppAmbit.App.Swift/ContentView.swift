import SwiftUI

private struct AppTab: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
}

struct ContentView: View {
    @State private var selectedTab = 0

    private let tabs: [AppTab] = [
        AppTab(title: "Crashes", icon: "exclamationmark.triangle"),
        AppTab(title: "Analytics", icon: "chart.bar"),
        AppTab(title: "Load", icon: "bolt.horizontal.circle"),
        AppTab(title: "RemoteConfig", icon: "arrow.2.circlepath.circle"),
        AppTab(title: "CMS", icon: "doc.richtext"),
        AppTab(title: "Database", icon: "cylinder.split.1x2")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: CrashesView()
                case 1: AnalyticsView()
                case 2: LoadView()
                case 3: RemoteConfigView()
                case 4: CmsView()
                default: DatabaseView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 28) {
                    ForEach(tabs.indices, id: \.self) { index in
                        Button {
                            selectedTab = index
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tabs[index].icon)
                                    .font(.system(size: 22))
                                Text(tabs[index].title)
                                    .font(.caption2)
                            }
                            .foregroundStyle(selectedTab == index ? Color.accentColor : Color.secondary)
                            .frame(minWidth: 64)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(height: 64)
            .background(.bar)
        }
        .ignoresSafeArea(.keyboard)
    }
}
