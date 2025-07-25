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
                Analytics.startSession { error in
                    if let error = error {
                        debugPrint("Error Start Session: \(error.localizedDescription)")
                    } else {
                        debugPrint("Successful Start Session")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
            
            Button("End Session") {
                Analytics.endSession { response in
                    if let response = response {
                        debugPrint("Error Start Session: \(response.localizedDescription)")
                    } else {
                        debugPrint("Successful End Session")
                    }                    
                }
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
        debugPrint("[AnalyticsView] Starting 5 concurrent error logs")
        
        for i in 1...5 {
            logsGroup.enter()
            concurrentQueue.async {
                let message = "Sending logs 5 after invalid token"
                let classFqn = "AnalyticsView"
                let properties = ["user_id": "1"]
                let createdAt = Date()
                
                Crashes.logError(message: message, properties: properties, classFqn: classFqn, createdAt: createdAt) { error in
                    if let error = error {
                        debugPrint("Failed to log error \(i): \(error.localizedDescription)")
                    } else {
                        debugPrint("Log \(i) recorded successfully")
                    }
                    logsGroup.leave()
                }            
            }
        }

        
        // 2. Event phase (They are executed one after the other)
        logsGroup.notify(queue: concurrentQueue) {
            debugPrint("[AnalyticsView] All logs completed. Starting 5 serial events")
            
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
                            debugPrint("Event \(i) failed: \(error.localizedDescription)")
                        } else {
                            debugPrint("Event \(i) tracked successfully")
                        }
                        eventsGroup.leave()
                    }
                }
            }
            
            // 3. Completion
            eventsGroup.notify(queue: .main) {
                debugPrint("[AnalyticsView] All operations completed successfully")
                showCompletionAlert = true
                overallGroup.leave()
            }
        }
        
        //Wait for full completion
        overallGroup.notify(queue: .main) {
            debugPrint("[AnalyticsView] Full test sequence completed")
        }
    }
}
