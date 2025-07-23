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
        .alert(isPresented: $showCompletionAlert) {
            Alert(
                title: Text("Info"),
                message: Text("5 events and 5 errors sent"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func onTokenRefreshTest() {
        let overallGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue.global(qos: .utility)
        let serialEventQueue = DispatchQueue(label: "com.appambit.analytics.eventQueue")
        
        overallGroup.enter() // Start of the entire process
        
        // 1. Error log phase (They run in parallel)
        let logsGroup = DispatchGroup()
        debugPrint("[TEST] Starting 5 concurrent error logs")
        
        for i in 1...5 {
            logsGroup.enter()
            concurrentQueue.async {
                Crashes.logError(
                    context: nil,
                    message: "Sending logs 5 after invalid token",
                    properties: ["user_id": "1"],
                    classFqn: "AnalyticsView",
                    exception: nil,
                    fileName: nil,
                    lineNumber: 0,
                    createdAt: Date()
                ) { error in
                    if let error = error {
                        print("Failed to log error \(i): \(error.localizedDescription)")
                    } else {
                        print("Log \(i) recorded successfully")
                    }
                    logsGroup.leave()
                }
            }
        }
        
        // 2. Event phase (They are executed one after the other)
        logsGroup.notify(queue: concurrentQueue) {
            debugPrint("[TEST] All logs completed. Starting 5 serial events")
            
            let eventsGroup = DispatchGroup()
            
            for i in 1...5 {
                eventsGroup.enter()
                serialEventQueue.async {
                    Analytics.trackEvent(
                        eventTitle: "Sending event 5 after invalid token",
                        data: ["Test Token": "5 events sent"],
                        createdAt: nil
                    ) { error in
                        if let error = error {
                            print("Event \(i) failed: \(error.localizedDescription)")
                        } else {
                            print("Event \(i) tracked successfully")
                        }
                        eventsGroup.leave()
                    }
                }
            }
            
            // 3. Completion
            eventsGroup.notify(queue: .main) {
                debugPrint("[TEST] All operations completed successfully")
                showCompletionAlert = true
                overallGroup.leave()
            }
        }
        
        // Opcional: Esperar por la finalización completa
        overallGroup.notify(queue: .main) {
            debugPrint("[TEST] Full test sequence completed")
        }
    }
}
