import SwiftUI
import AppAmbit
import Network
import Foundation

struct CrashesView: View {
    @State private var userId: String = UUID().uuidString
    @State private var email: String = "test@gmail.com"
    @State private var messgeCutsom: String = "Test Log Message"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Info"
    
    init() {

    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                VStack {
                    Button("Did the app crash during your last session?") {
                        Crashes.didCrashInLastSession { didCrash in
                            DispatchQueue.main.async {
                                self.alertMessage = didCrash
                                ? "Application crashed in the last session"
                                : "Application did not crash in the last session"
                                self.showAlert = true
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
                .alert("Info", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("User Id", text: $userId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                        .padding(.horizontal)
                    
                    Button("Change user id") {
                        Analytics.setUserId(userId) { error in
                            if let error = error {
                                debugPrint("Failed to set user ID: \(error)")
                            } else {
                                debugPrint("User ID set successfully")
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
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("User email", text: $email)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                        .padding(.horizontal)
                    
                    Button("Change user email") {
                        Analytics.setEmail(email)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Test Log Message", text: $messgeCutsom)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 2)
                        )
                        .padding(.horizontal)
                    
                    Button("Send Custom LogError") {
                        onTestErrorLogClicked()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Button("Send Default LogError") {
                    onTestLog()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Send Exception LogError") {
                    sendTestError()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Send ClassInfo LogError") {
                    onSendTestLogWithClassFQN()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Generate the last 30 daily errors") {
                    onGenerate30daysTestErrors()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Generates the last 30 daily crashes") {
                    onGenerate30daysTestCrash()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Throw new Crash") {
                    let array = NSArray()
                    _ = array.object(at: 10)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Button("Generate Test Crash") {
                    Crashes.generateTestCrash()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
            }
        }
        .alert("Info", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func onTestErrorLogClicked() {
        Crashes.logError(message: messgeCutsom) { result in
            
            if result != nil {
                debugPrint("[CrashesView] Error sending Log Error: \(result?.localizedDescription ?? "")")
            } else {
                debugPrint("[CrashesView] Log Error sent successfully")
            }
            
            DispatchQueue.main.async {
                self.showAlert = true
                self.alertMessage = "LogError Sent"
            }
        }
    }
    
    private func onTestLog() {
        Crashes.logError(message: "Test Log Error",
                         properties: ["user_id": "1"]) { error in
            if let error = error {
                debugPrint("[CrashesView] Error sending Log Error: \(error.localizedDescription)")
            } else {
                debugPrint("[CrashesView] Log Error sent successfully")
            }
            
            DispatchQueue.main.async {
                self.showAlert = true
                self.alertMessage = "LogError Sent"
            }
        }
    }
    
    func sendTestError() {
        do {
            throw NSError(domain: "com.appambit.crashview", code: 1234, userInfo: [NSLocalizedDescriptionKey: "Test error Exception"])
        } catch {
            Crashes.logError(exception: error, properties: ["user_id": "1"]) {error in
                if let error = error {
                    debugPrint("[CrashesView] Log Error sent with: \(error.localizedDescription)")
                } else {
                    debugPrint("[CrashesView] Log Error sent successfully")
                }
                
                DispatchQueue.main.async {
                    self.showAlert = true
                    self.alertMessage = "LogError Sent"
                }
            }
        }
    }
    
    func onSendTestLogWithClassFQN() {
        let classFullName = String(reflecting: type(of: self))
        Crashes.logError(
            message: "Test Log Error",
            properties: ["user_id": "1"],
            classFqn: classFullName
        ) { error in
            if let error = error {
                debugPrint("[CrashesView] Error sending Log Error: \(error.localizedDescription)")
            } else {
                debugPrint("[CrashesView] Log Error sent successfully")
            }
            
            DispatchQueue.main.async {
                self.showAlert = true
                self.alertMessage = "LogError Sent"
            }
        }
    }
    
    func onGenerate30daysTestErrors() {
        if NetworkMonitor.isConnected() {
            self.alertMessage = "Turn off internet and try again"
            self.showAlert = true
            return
        }
        
        struct Item { let start: Date; let end: Date; let createdAt: Date }
        
        let totalDays = 30
        let delayBetweenLogsSeconds: TimeInterval = 0.5
        let now = Date()
        var items = [Item]()
        items.reserveCapacity(totalDays)
        
        for index in 1...totalDays {
            let daysToSubtract = totalDays - index
            let start = Calendar.current.date(byAdding: .day, value: -daysToSubtract, to: now) ?? now
            let end = start.addingTimeInterval(delayBetweenLogsSeconds)
            items.append(Item(start: start, end: end, createdAt: start))
        }
        
        func logErrorAwait(message: String, createdAt: Date) async {
            await withCheckedContinuation { cont in
                Crashes.logError(message: message, createdAt: createdAt) { _ in
                    cont.resume()
                }
            }
        }
        
        _ = try? StorableApp.shared.putSessionData(timestamp: Date(), sessionType: "end")
        
        Task(priority: .utility) {
            let entered = await ConcurrencyApp.shared.tryEnter()
            guard entered else { return }
            defer { Task { await ConcurrencyApp.shared.leave() } }
            
            for item in items {
                do {
                    try StorableApp.shared.putSessionData(timestamp: item.start, sessionType: "start")
                } catch {
                    debugPrint("Error inserting start session: \(error)")
                    continue
                }
                
                await logErrorAwait(message: "Test 30 Last Days Errors", createdAt: item.createdAt)
                
                do {
                    try StorableApp.shared.updateLogsWithCurrentSessionId()
                    try StorableApp.shared.putSessionData(timestamp: item.end, sessionType: "end")
                } catch {
                    debugPrint("Error inserting end session: \(error)")
                    continue
                }
            }
            
            await MainActor.run {
                self.alertMessage = "Logs generated, turn on internet"
                self.showAlert = true
            }
        }
    }
    
    func onGenerate30daysTestCrash() {
        if NetworkMonitor.isConnected() {
            self.alertMessage = "Turn off internet and try again"
            self.showAlert = true
            return
        }

        struct Item { let start: Date; let end: Date; let createdAt: Date }

        let totalDays = 30
        let delayBetweenLogsSeconds: TimeInterval = 4
        let now = Date()
        var items = [Item]()
        items.reserveCapacity(totalDays)

        for index in 1...totalDays {
            let daysToSubtract = totalDays - index
            let start = Calendar.current.date(byAdding: .day, value: -daysToSubtract, to: now) ?? now
            let end = start.addingTimeInterval(delayBetweenLogsSeconds)
            items.append(Item(start: start, end: end, createdAt: start))
        }

        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            self.alertMessage = "Failed to access Application Support directory"
            self.showAlert = true
            return
        }
        let crashLogsDir = appSupportDirectory.appendingPathComponent("CrashLogs")
        if !FileManager.default.fileExists(atPath: crashLogsDir.path) {
            do { try FileManager.default.createDirectory(at: crashLogsDir, withIntermediateDirectories: true) }
            catch {
                debugPrint("\(error.localizedDescription)")
                return
            }
        }

        let baseException: Error = NSError(
            domain: "com.appambit.crashview",
            code: 1234,
            userInfo: [NSLocalizedDescriptionKey: "Error crash 30 daily"]
        )

        _ = try? StorableApp.shared.putSessionData(timestamp: Date(), sessionType: "end")

        Task(priority: .utility) {
            let entered = await ConcurrencyApp.shared.tryEnter()
            guard entered else { return }
            defer { Task { await ConcurrencyApp.shared.leave() } }

            for (idx, item) in items.enumerated() {
                do {
                    try StorableApp.shared.putSessionData(timestamp: item.start, sessionType: "start")
                } catch {
                    debugPrint("Error inserting start session: \(error)")
                    continue
                }

                let sessionId = (try? StorableApp.shared.getCurrentOpenSessionId()) ?? ""

                var exceptionInfo = ExceptionModel.fromError(baseException, sessionId: sessionId)
                exceptionInfo.createdAt = item.createdAt
                exceptionInfo.crashLogFile = item.createdAt.ISO8601Format() + "_\(idx + 1)"

                do {
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .iso8601
                    encoder.outputFormatting = .prettyPrinted

                    let stamp = item.createdAt.formatted(.iso8601.dateSeparator(.omitted).timeSeparator(.omitted))
                    let fileURL = crashLogsDir.appendingPathComponent("crash_\(stamp)_\(idx + 1).json")

                    try encoder.encode(exceptionInfo).write(to: fileURL)
                    debugPrint("Crash file saved: \(fileURL.lastPathComponent)")
                } catch {
                    debugPrint("Error saving crash file: \(error.localizedDescription)")
                }
                
                do {
                    try StorableApp.shared.putSessionData(timestamp: item.end, sessionType: "end")
                } catch {
                    debugPrint("Error inserting end session: \(error)")
                    continue
                }
            }

            await MainActor.run {
                self.alertMessage = "Crashes generated, turn on internet"
                self.showAlert = true
            }
        }
    }

}
