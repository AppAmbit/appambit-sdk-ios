import SwiftUI
import AppAmbit

struct LoadView: View {
    @State private var testMessage: String = "Test Message"
    @State private var alertMessage: String = ""
    @State private var showAlert = false
    @State private var eventsLabel = ""
    @State private var logsLabel = ""
    @State private var sessionsLabel = ""
    @State private var showMessageProgressEvents = false
    @State private var showMessageProgressLogs = false
    @State private var showMessageProgressSessions = false
    private let limit = 500
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Test Message", text: $testMessage)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 2)
                    )
                    .padding(.horizontal)
                
                
                if showMessageProgressLogs {
                    Text(logsLabel)
                        .autocapitalization(.none)
                        .padding()
                        .padding(.horizontal)
                }
                
                Button("Send 500 Logs") {
                    onGenerate500Logs()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                
                if showMessageProgressEvents {
                    Text(eventsLabel)
                        .autocapitalization(.none)
                        .padding()
                        .padding(.horizontal)
                }
                
                Button("Send 500 events") {
                    onGenerate500Events()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                if showMessageProgressSessions {
                    Text(sessionsLabel)
                        .autocapitalization(.none)
                        .padding()
                        .padding(.horizontal)
                }
                
                Button("Send 500 Sessions") {
                    onGenerate500Sessions()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
            
            }
        }.alert("Info", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func onGenerate500Events() {
        showMessageProgressEvents = true
        let properties = ["Test 500": "Events"]

        Task { @MainActor in
            for counter in 1...limit {
                self.eventsLabel = "Sending event: \(counter) of \(limit)"

                Analytics.trackEvent(eventTitle: testMessage, data: properties) { response in
                    if let error = response {
                        debugPrint("Event response with error: \(error.localizedDescription)")
                    } else {
                        debugPrint("Event sent successfully")
                    }
                }

                let ms: UInt64 = NetworkMonitor.isConnected() ? 1000 : 5
                try? await Task.sleep(nanoseconds: ms * 1_000_000)
            }

            self.eventsLabel = "\(limit) Events generated"
            self.alertMessage = "\(limit) Events generated"
            self.showAlert = true
        }
    }

    func onGenerate500Logs() {
        showMessageProgressLogs = true

        Task { @MainActor in
            for counter in 1...limit {
                self.logsLabel = "Sending Log: \(counter) of \(limit)"

                Crashes.logError(message: testMessage) { response in
                    if let error = response {
                        debugPrint("Log response with error: \(error.localizedDescription)")
                    } else {
                        debugPrint("Log sent successfully")
                    }
                }

                let ms: UInt64 = NetworkMonitor.isConnected() ? 1000 : 5
                try? await Task.sleep(nanoseconds: ms * 1_000_000)
            }

            self.logsLabel = "\(limit) Log generated"
            self.alertMessage = "\(limit) Logs generated"
            self.showAlert = true
            self.showMessageProgressLogs = false
        }
    }
    
    func onGenerate500Sessions() {
        showMessageProgressSessions = true
        let total = limit

        Task { @MainActor in
            for counter in 1...total {

                Analytics.startSession { error in
                    if let error = error {
                        debugPrint("Error Start Session: \(error.localizedDescription)")
                    } else {
                        debugPrint("Successful Start Session")
                    }
                }

                self.sessionsLabel = "Sending session: \(counter) of \(total)"

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                Analytics.endSession { error in
                    if let error = error {
                        debugPrint("Error End Session: \(error.localizedDescription)")
                    } else {
                        debugPrint("Successful End Session")
                    }
                }

                print("Session \(counter) sent")

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            self.showMessageProgressSessions = false
            self.alertMessage = "\(total) Sessions generated"
            self.showAlert = true
            self.showMessageProgressSessions = false
        }
    }
}
