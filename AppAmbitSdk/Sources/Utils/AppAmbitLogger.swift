import Foundation


public final class AppAmbitLogger {
    
    public static func log(
        error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let className = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        debugPrint("[\(className).\(function):\(line)]: \(error.localizedDescription)")
    }
    
    public static func log(
        message: String,
        file: String = #file,
        function: String = #function
    ) {
        let className = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        debugPrint("[\(className).\(function)]: \(message)")
    }

    public static func buildError(message: String, code: Int = 0) -> NSError {
        return NSError(
            domain: "com.appambit.sdk",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
