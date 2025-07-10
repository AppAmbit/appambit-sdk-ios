import SwiftUI

struct AnalyticsView: View {
    var body: some View {
        VStack(spacing: 25) {
            Text("Analytics View")
                .padding()
                .background(Color.teal, in: RoundedRectangle.init(cornerRadius: 10))
        }
        .padding()
    }
}
