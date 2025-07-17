import Foundation

public class Crashes {
    
    public static func logError(
        context: Any?,
        message: String?,
        properties: [String: String]?,
        classFqn: String?,
        exception: NSException?,
        fileName: String?,
        lineNumber: Int,
        createdAt: Date?
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
            createdAt: createdAt
        )
    }

}
