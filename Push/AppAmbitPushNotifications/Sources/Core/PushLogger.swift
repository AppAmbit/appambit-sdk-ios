import Foundation

/// Internal logger for the AppAmbit Push SDK.
public class PushLogger {
    
    public nonisolated(unsafe) static var debugMode = false
    private static let tag = "[AppAmbitPushSDK]"
    
    public static func log(_ message: String) {
        if debugMode {
            print("\(tag) \(message)")
        }
    }
    
    public static func error(_ message: String) {
        print("\(tag) ERROR: \(message)")
    }
    
    public static func raw(_ message: String) {
        if debugMode {
            print(message)
        }
    }
}
