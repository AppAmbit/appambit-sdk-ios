import Foundation

final class Logging: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "com.appambit.logging.queue", qos: .utility)
    private static let tag = "Logging"
    
    
    static func logEvent(
        message: String?,
        logType: LogType,
        exception: NSException,
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int64,
        createdAt: Date?
    ) {
        let exceptionInfo = ExceptionInfo.fromNSException(exception)
        logEvent(message: message, logType: logType, exceptionInfo: exceptionInfo, properties: properties, classFqn: classFqn, fileName: fileName, lineNumber: lineNumber, createdAt: createdAt)
    }
        
    static func logEvent(
        message: String?,
        logType: LogType,
        exceptionInfo: ExceptionInfo?,
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int64,
        createdAt: Date?
    ) {
        let stackTrace = (exceptionInfo?.stackTrace != nil && !(exceptionInfo?.stackTrace.isEmpty ?? true))
            ? exceptionInfo!.stackTrace
        : AppConstants.noStackTraceAvailable

        let version = ServiceContainer.shared.appInfoService.appVersion ?? ""
        let build = ServiceContainer.shared.appInfoService.build ?? ""
        let appVersionInfo = "\(version) (\(build))"
        
        let log = LogEntity()
        log.id = UUID().uuidString
        log.appVersion = appVersionInfo
        log.classFQN = (exceptionInfo?.classFullName == "" ? (classFqn == "" ? AppConstants.unknownClass : classFqn) : exceptionInfo?.classFullName)
        log.fileName = exceptionInfo?.fileNameFromStackTrace == "" ? fileName == "" ? AppConstants.unknownFileName : fileName : exceptionInfo?.fileNameFromStackTrace
        log.lineNumber = (exceptionInfo?.lineNumberFromStackTrace != 0) ? Int64(exceptionInfo!.lineNumberFromStackTrace) : lineNumber
        log.message = exceptionInfo?.message ?? (message ?? "")
        log.stackTrace = stackTrace
        log.context = properties ?? [:]
        log.type = logType
        log.file = logType == .crash ? getFile(exceptionIn: exceptionInfo) : nil
        log.createdAt = createdAt
        
        sendOrSaveLogEvent(log)
    }
    
    static func getFile(exceptionIn: ExceptionInfo?) -> MultipartFile? {
               
        let fileName = CrashHandler.generateLogFileName()
        let mimeType = "text/plain"
        
        if let content = exceptionIn?.crashLogFile {
            return MultipartFile(fileName: fileName, mimeType: mimeType, data: Data(content.utf8))
        }
        
        return MultipartFile(fileName: fileName, mimeType: mimeType, data: Data("".utf8))
    }
    
    private static func sendOrSaveLogEvent(_ logEntity: LogEntity) {
        queue.sync {
            let apiService = ServiceContainer.shared.apiService
            let logEndpoint = LogEndpoint(log: logEntity)
            
            let logCopy = Log()
            logCopy.appVersion = logEntity.appVersion
            logCopy.classFQN = logEntity.classFQN
            logCopy.fileName = logEntity.fileName
            logCopy.lineNumber = logEntity.lineNumber
            logCopy.message = logEntity.message
            logCopy.stackTrace = logEntity.stackTrace
            logCopy.context = logEntity.context
            logCopy.type = logEntity.type
            logCopy.file = logEntity.file
            
            apiService.executeRequest(logEndpoint, responseType: LogResponse.self) { result in
                
                if result.errorType != .none {
                    storeLogInDb(logEntity)
                    return
                }
                
                debugPrint("\(tag): Log send")
            }            
        }
    }

    private static func storeLogInDb(_ log: LogEntity) {
        queue.async {
            do {
                let storable: StorageService = ServiceContainer.shared.storageService
                try storable.putLogEvent(log)
                print("\(tag): Log event stored in database")
            } catch {
                print("\(tag): Failed to store log event: \(error.localizedDescription)")
            }
        }
    }

}
