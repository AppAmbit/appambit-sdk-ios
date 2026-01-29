import SwiftUI
import AppAmbit
import AppAmbitPushNotifications
import Network
import Foundation
import UserNotifications

struct CrashesView: View {
    @State private var userId: String = UUID().uuidString
    @State private var email: String = "test@gmail.com"
    @State private var messgeCutsom: String = "Test Log Message"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Info"
    @State private var notificationButtonTitle = "Enable Notifications"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                VStack {
                    // Notification Button
                    Button(notificationButtonTitle) {
                        setupNotificationButton()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onAppear {
                        updateNotificationButtonState()
                    }
                    
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
                    
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 96/255, green: 120/255, blue: 141/255)) // azul-gris
                .foregroundColor(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(true)
                
                Button("Generates the last 30 daily crashes") {
                    
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(red: 96/255, green: 120/255, blue: 141/255)) // azul-gris
                .foregroundColor(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(true)
                
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
    
    // MARK: - Push Notifications Setup
    
    /// Example: Simple push notifications toggle button
    /// This demonstrates a minimal integration without SDK UI helpers.
    private func setupNotificationButton() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authStatus = settings.authorizationStatus
            DispatchQueue.main.async {
                switch authStatus {
                case .notDetermined:
                    PushNotifications.requestNotificationPermission { granted in
                        if granted {
                            self.notificationButtonTitle = "Disable Notifications"
                            self.enableNotifications()
                        } else {
                            self.showAlertWithMessage(
                                title: "Info",
                                message: "Permission denied. Notifications cannot be enabled."
                            )
                        }
                        self.updateNotificationButtonState()
                    }
                    
                case .authorized, .provisional:
                    let newState = !PushNotifications.isNotificationsEnabled()
                    PushNotifications.setNotificationsEnabled(newState) { success in
                        let message = success
                        ? "Notifications have been \(newState ? "enabled" : "disabled")."
                        : "Permission granted, but sync is pending or failed."
                        self.showAlertWithMessage(
                            title: success ? "Notification Status" : "Info",
                            message: message
                        )
                        self.updateNotificationButtonState()
                    }
                    
                case .denied:
                    self.showAlertWithMessage(
                        title: "Info",
                        message: "Notifications are disabled in Settings. Please enable them manually."
                    )
                    self.updateNotificationButtonState()
                    
                @unknown default:
                    self.showAlertWithMessage(title: "Info", message: "Unknown permission status.")
                    self.updateNotificationButtonState()
                }
            }
        }
    }
    
    private func updateNotificationButtonState() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authStatus = settings.authorizationStatus
            DispatchQueue.main.async {
                switch authStatus {
                case .notDetermined:
                    self.notificationButtonTitle = "Request Notification Permission"
                    
                case .authorized, .provisional:
                    let isEnabled = PushNotifications.isNotificationsEnabled()
                    self.notificationButtonTitle = isEnabled ? "Disable Notifications" : "Enable Notifications"
                    
                case .denied:
                    self.notificationButtonTitle = "Open Settings (Permission Denied)"
                    
                @unknown default:
                    self.notificationButtonTitle = "Enable Notifications"
                }
            }
        }
    }
    
    private func enableNotifications() {
        PushNotifications.setNotificationsEnabled(true) { success in
            let message = success
            ? "Notifications have been enabled."
            : "Permission granted, but sync is pending or failed."
            self.showAlertWithMessage(title: success ? "Notification Status" : "Info", message: message)
            self.updateNotificationButtonState()
        }
    }
    
    private func showAlertWithMessage(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
