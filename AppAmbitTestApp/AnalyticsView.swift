import SwiftUI
import AppAmbit

struct AnalyticsView: View {
    @State private var showCompletionAlert = false
    @State private var messageAlert = ""
    var body: some View {
        ScrollView {
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
                
                Button("Generate the last 30 daily sessions") {
                    generateTestSessionsForLast30Days()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Send 'Button Clicked' Event w/ property") {
                    Analytics.trackEvent(eventTitle: "ButtonClicked", data: ["Count": "41"]) { response in
                        if let response = response {
                            debugPrint("Error Track Event: \(response.localizedDescription)")
                        } else {
                            debugPrint("Event sent successfully")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                            
                Button("Send Default Event w/ property") {
                    Analytics.generateTestEvent() { response in
                        if let response = response {
                            debugPrint("Error Track Event: \(response.localizedDescription)")
                        } else {
                            debugPrint("Event sent successfully")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Send Max-300-Length Event") {
                    onClickedTestLimitsEvent()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)

                Button("Send Max-20-Properties Event") {
                    onClickedTestMaxPropertiesEven()                    
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Send Batch of 220 Events") {
                    onGenerateBatchEvents()
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
                    message: Text(messageAlert),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func onClickedTestLimitsEvent() {
        let _300Characters = "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890";
        let _300Characters2 = "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678902";
        
        let properties = [
            _300Characters: _300Characters,
            _300Characters2: _300Characters2
        ]
        
        Analytics.trackEvent(eventTitle: _300Characters, data: properties) { response in
            if let response = response {
                debugPrint("Error Track Event: \(response.localizedDescription)")
            } else {
                debugPrint("Event sent successfully")
            }
        }
    }
    
    private func onClickedTestMaxPropertiesEven() {
        let properties = [
            "01": "01",
            "02": "02",
            "03": "03",
            "04": "04",
            "05": "05",
            "06": "06",
            "07": "07",
            "08": "08",
            "09": "09",
            "10": "10",
            "11": "11",
            "12": "12",
            "13": "13",
            "14": "14",
            "15": "15",
            "16": "16",
            "17": "17",
            "18": "18",
            "19": "19",
            "20": "20",
            "21": "21",
            "22": "22",
            "23": "23",
            "24": "24",
            "25": "25",
        ]
        Analytics.trackEvent(eventTitle: "TestMaxProperties", data: properties) { response in
            if let response = response {
                debugPrint("Error Track Event: \(response.localizedDescription)")
            } else {
                debugPrint("Event sent successfully")
            }
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
                messageAlert = "5 events and 5 errors sent"
                overallGroup.leave()
            }
        }
        
        //Wait for full completion
        overallGroup.notify(queue: .main) {
            debugPrint("[AnalyticsView] Full test sequence completed")
        }
    }
    
    func generateTestSessionsForLast30Days() {
        if NetworkMonitor.shared.isConnected {
            self.messageAlert = "Turn off internet and try again"
            self.showCompletionAlert = true
             return
         }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        let sessionCount = 30
        let randomMinutesRange = 21...120
        for i in 0..<sessionCount {
            
            guard let sessionDay = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            
            let randomHour = Int.random(in: 0..<23)
            let randomMinute = Int.random(in: 0..<60)
            let startSessionDate = calendar.date(bySettingHour: randomHour, minute: randomMinute, second: 0, of: sessionDay)!

            do {
                try StorableApp.shared.putSessionData(timestamp: startSessionDate, sessionType: "start")
            } catch {
                debugPrint("Error inserting start session: \(error)")
            }

            let randomDurationMinutes = Int.random(in: randomMinutesRange)
            let endSessionDate = startSessionDate.addingTimeInterval(TimeInterval(randomDurationMinutes * 60))

            do {
                try StorableApp.shared.putSessionData(timestamp: endSessionDate, sessionType: "end")
            } catch {
                debugPrint("Error inserting end session: \(error)")
            }
        }
        
        DispatchQueue.main.async {
            self.messageAlert = "Sessions generated, turn on internet"
            self.showCompletionAlert = true
        }

        debugPrint("\(sessionCount) test sessions were inserted.")
    }
    
    func onGenerateBatchEvents() {
        if NetworkMonitor.shared.isConnected {
            self.messageAlert = "Turn off internet and try again"
            self.showCompletionAlert = true
            return
        }
        let limit:Int = 220
        for index in 1...limit {
           
            Analytics.trackEvent(eventTitle: "Test Batch TrackEvent", data: ["test1":"test1"]) { response in
                if let response = response {
                    debugPrint("[AnalyticsView] Error Track Event: \(response.localizedDescription)")
                } else {
                    debugPrint("[AnalyticsView] Event sent successfully")
                }
                
                if index == limit {
                    DispatchQueue.main.async {
                        self.messageAlert = "Events generated, turn on internet"
                        self.showCompletionAlert = true
                    }
                }
            }
        }
    }
}
