import SwiftUI

struct LoadView: View {
    var body: some View {
        VStack(spacing: 25) {
            Text("Load View")
                .padding()
                .background(Color.teal, in: RoundedRectangle.init(cornerRadius: 10))
        }
        .padding()
    }
}
