import SwiftUI
import AppAmbit
import Network
import Foundation

struct CrashesView: View {
    @State private var userId: String = UUID().uuidString
    @State private var email: String = "test@gmail.com"
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 25) {
            VStack {
                Button("Did the app crash during your last session?") {
                    Task {
                        let didCrash = Crashes.didCrashInLastSession()
                        alertMessage = didCrash
                            ? "Application crashed in the last session"
                            : "Application did not crash in the last session"
                        showAlert = true
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
                    Analytics.setUserId(userId)
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
        .alert("Info", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}
