import Foundation

public final class AppAmbitLogger {
    public static func log(error: Error, context: String? = nil) {
        if let context = context {
            debugPrint("\(context): \(error.localizedDescription)")
        } else {
            debugPrint("Error: \(error.localizedDescription)")
        }
    }
    
    public static func log(message: String, context: String? = nil) {
        if let context = context {
            debugPrint("\(context): \(message)")
        } else {
            debugPrint("Message: \(message)")
        }
    }
    
    public static func buildError(message:String, code: Int = 0) -> NSError {
        return NSError(
            domain: "com.appambit.sdk",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
