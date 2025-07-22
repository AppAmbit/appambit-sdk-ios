import Foundation

public struct ExceptionInfo: Codable {
    let type: String
    let message: String?
    let stackTrace: String
    let source: String?
    let innerException: String?
    let fileNameFromStackTrace: String
    let classFullName: String
    let lineNumberFromStackTrace: Int64
    public var crashLogFile: String?
    public var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case message = "Message"
        case stackTrace = "StackTrace"
        case source = "Source"
        case innerException = "InnerException"
        case fileNameFromStackTrace = "FileNameFromStackTrace"
        case classFullName = "ClassFullName"
        case lineNumberFromStackTrace = "LineNumberFromStackTrace"
        case crashLogFile = "CrashLogFile"
        case createdAt =  "CreatedAt"
    }

    public static func fromNSException(_ exception: NSException) -> ExceptionInfo {
        let stackTrace = exception.callStackSymbols
        let (fileName, className, lineNumber) = parseStackTrace(stackTrace)

        var innerDescription: String? = nil
        if let underlying = exception.userInfo?[NSUnderlyingErrorKey] as? NSError {
            innerDescription = String(describing: underlying)
        }

        let source = stackTrace.first.flatMap { line -> String? in
            let components = line.split(separator: " ")
            if components.count > 1 {
                return String(components[1])
            }
            return nil
        }
                
        let backtraceString: String = stackTrace.joined(separator: "\n")
        return ExceptionInfo(
            type: exception.name.rawValue,
            message: exception.reason,
            stackTrace: backtraceString,
            source: source,
            innerException: innerDescription,
            fileNameFromStackTrace: fileName ?? AppConstants.unknownClass,
            classFullName: className ?? "UnknownClass",
            lineNumberFromStackTrace: lineNumber ?? 0,
            crashLogFile: CrashFileGenerator.generateCrashLog(exception: exception, stackTrace: nil),
            createdAt: DateUtils.utcNow
        )
    }
    
    static func fromSignalException(signalName: String, source: String?, stackTrace: String, fileNameFromStackTrace: String, classFullName: String, lineNumberFromStackTrace: Int64) -> ExceptionInfo {
        
        
        return ExceptionInfo(
            type: signalName,
            message: "Application terminated due to signal: \(signalName)",
            stackTrace: stackTrace,
            source: source,
            innerException: nil,
            fileNameFromStackTrace: fileNameFromStackTrace,
            classFullName: classFullName,
            lineNumberFromStackTrace: lineNumberFromStackTrace,
            crashLogFile: CrashFileGenerator.generateCrashLog(exception: nil, stackTrace: stackTrace),
            createdAt: DateUtils.utcNow
        )
    }

    private static func parseStackTrace(_ stackTrace: [String]) -> (String?, String?, Int64?) {
        for symbol in stackTrace {
            if let swiftRange = symbol.range(of: ".swift:"),
               let fileStart = symbol[..<swiftRange.lowerBound].lastIndex(of: "/") {
                
                let fileName = String(symbol[fileStart...swiftRange.upperBound])
                    .replacingOccurrences(of: "/", with: "")
                let className = fileName.replacingOccurrences(of: ".swift", with: "")
                
                let afterFile = symbol[swiftRange.upperBound...]
                let lineNumberString = afterFile.prefix { $0.isNumber }
                
                if let lineNumber = Int64(lineNumberString) {
                    return (fileName, className, lineNumber)
                }
            }
        }
        return (nil, nil, nil)
    }
}
