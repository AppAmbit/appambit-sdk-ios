import Foundation

public class Crashes {
    public static func logError(
        context: Any? = nil,
        message: String? = nil,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        exception: NSException? = nil,
        fileName: String? = nil,
        lineNumber: Int64 = #line,
        createdAt: Date? = nil,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        Logging.logEvent(
            context: context,
            message: message,
            logType: .error,
            exception: exception,
            properties: properties,
            classFqn: classFqn,
            fileName: fileName,
            lineNumber: lineNumber,
            createdAt: createdAt,
            completion: completion
        )
    }
}
