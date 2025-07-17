import SwiftUI
import AppAmbit

struct AnalyticsView: View {
    @State private var showCompletionAlert = false
    
    var body: some View {
        VStack(spacing: 25) {
            Button("Invalidate Token") {
                Analytics.clearToken()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            
            Button("Token refresh test") {
                onTokenRefreshTest()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .padding()
        .alert(isPresented: $showCompletionAlert) {
            Alert(
                title: Text("Info"),
                message: Text("5 events and 5 errors sent"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func onTokenRefreshTest() {
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)

        Analytics.clearToken()

       print("[Test] Enviando 5 logs concurrentes con token vacío")
        for i in 1...5 {
            group.enter()
            queue.async {
                Crashes.logError(
                    context: nil,
                    message: "Sending logs 5 after invalid token",
                    properties: ["user_id": "1"],
                    classFqn: "AnalyticsView",
                    exception: nil,
                    fileName: nil,
                    lineNumber: 0,
                    createdAt: Date()
                )
                group.leave()
            }
        }

       group.notify(queue: .main) {
            print("[Test] Terminó batch de Logs. Limpiando token para Events.")
            Analytics.clearToken()

            let eventGroup = DispatchGroup()

            print("[Test] Enviando 5 eventos concurrentes con token vacío")
            for i in 1...5 {
                eventGroup.enter()
                queue.async {
                    Analytics.trackEvent(
                        eventTitle: "Sending events 5 after invalid token",
                        data: ["Test Token": "5 events sent"],
                        createdAt: nil
                    )
                    eventGroup.leave()
                }
            }

            eventGroup.notify(queue: .main) {
                print("[Test] Se enviaron 5 logs y 5 eventos con renovación de token en concurrencia.")
                showCompletionAlert = true
            }
        }
    }
}
