import Foundation

final class Logging: @unchecked Sendable {
    
    private static let queue = DispatchQueue(label: "com.appambit.logging.queue", qos: .utility)
    private static let tag = "Logging"
    
    static func logEvent(
        context: Any?,
        message: String?,
        logType: LogType,
        exception: NSException? = nil,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        fileName: String? = nil,
        lineNumber: Int64 = #line,
        createdAt: Date? = nil,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let file = (logType == .crash) ?
            MultipartFile(
                fileName: "crash_log.txt",
                mimeType: "text/plain",
                data: Data("Crash report content".utf8)
            ) : nil
        
        let appVersion = "\(ServiceContainer.shared.appInfoService.appVersion ?? "") (\(ServiceContainer.shared.appInfoService.build ?? ""))"
        

        let log = Log()
        log.appVersion = appVersion
        log.classFQN = classFqn ?? AppConstants.unknownClass
        log.fileName = fileName ?? AppConstants.unknownFileName
        log.lineNumber = lineNumber
        log.message = message ?? ""
        log.stackTrace = exception?.callStackSymbols.joined(separator: "\n") ?? AppConstants.noStackTraceAvailable
        log.context = properties ?? [:]
        log.type = logType
        log.file = file
        
        sendOrSaveLogEventAsync(log) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    private static func sendOrSaveLogEventAsync(_ log: Log, completion: (@Sendable (Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            let logEndpoint = LogEndpoint(log: log)
            
            let apiService = ServiceContainer.shared.apiService
            apiService.executeRequest(logEndpoint, responseType: LogResponse.self) { (result: ApiResult<LogResponse>) in
                if result.errorType != .none {
                    AppAmbitLogger.log(message: result.message ?? "Unknown")
                    completion?(AppAmbitLogger.buildError(message: result.message ?? "", code: 101))
                } else {
                    completion?(nil)
                }
            }
        }
        queue.async(execute: workItem)
    }
}
