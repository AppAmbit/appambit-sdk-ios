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
                    debugPrint("[CrashesView] Log Error sent successfully")
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
    
}
