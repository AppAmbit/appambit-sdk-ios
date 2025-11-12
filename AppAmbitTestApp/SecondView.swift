import SwiftUI

struct SecondView: View {
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            Text("Second Screen")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
        }
    }
}
