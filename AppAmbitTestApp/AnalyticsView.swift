import SwiftUI
import AppAmbit

struct AnalyticsView: View {
    var body: some View {
        VStack(spacing: 25) {
            Button("Start Session") {
                Analytics.startSession()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            
            Button("End Session") {
                Analytics.endSession()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            
        }
        .padding()        
    }
}
