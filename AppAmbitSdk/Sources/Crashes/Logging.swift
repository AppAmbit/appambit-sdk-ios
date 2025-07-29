import Foundation

final class Logging: @unchecked Sendable {
    private static let queue = DispatchQueue(label: "com.appambit.logging.queue", qos: .utility)
    private static let tag = "Logging"
        
    static func logEvent(
        message: String?,
        logType: LogType,
        exception: Error?,
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int64,
        createdAt: Date?,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let exception = exception != nil ? ExceptionInfo.fromError(exception!) : nil
        logEvent(message: message, logType: logType, exceptionInfo: exception, properties: properties, classFqn: classFqn, fileName: fileName, lineNumber: lineNumber, createdAt: createdAt, completion: completion)
    }
        
    static func logEvent(
        message: String?,
        logType: LogType,
        exceptionInfo: ExceptionInfo?,
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int64,
        createdAt: Date?,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        
        if !SessionManager.isSessionActive {
            let message = "There is no active session"
            AppAmbitLogger.log(message: message)
            completion?(AppAmbitLogger.buildError(message: message))
            return
         }
        
        let stackTrace = (exceptionInfo?.stackTrace != nil && !(exceptionInfo?.stackTrace.isEmpty ?? true))
            ? exceptionInfo!.stackTrace
        : AppConstants.noStackTraceAvailable

        let version = ServiceContainer.shared.appInfoService.appVersion ?? ""
        let build = ServiceContainer.shared.appInfoService.build ?? ""
        let appVersionInfo = "\(version) (\(build))"
        
        let log = LogEntity()
        log.id = UUID().uuidString
        log.appVersion = appVersionInfo
        log.classFQN = (exceptionInfo?.classFullName.isEmpty ?? true) ? (classFqn?.isEmpty ?? true ? AppConstants.unknownClass : classFqn) : exceptionInfo?.classFullName
        log.fileName = (exceptionInfo?.fileNameFromStackTrace.isEmpty ?? true) ? fileName?.isEmpty ?? true ? AppConstants.unknownFileName : fileName : exceptionInfo?.fileNameFromStackTrace
        log.lineNumber = (exceptionInfo != nil && exceptionInfo!.lineNumberFromStackTrace != 0)
            ? exceptionInfo!.lineNumberFromStackTrace
            : lineNumber
        log.message = (exceptionInfo?.message?.isEmpty == false) ? exceptionInfo!.message! : (message ?? "")
        log.stackTrace = stackTrace
        log.context = properties ?? [:]
        log.type = logType
        log.file = logType == .crash ? getFile(exceptionIn: exceptionInfo) : nil
        log.createdAt = createdAt ?? DateUtils.utcNow
        
        sendOrSaveLogEvent(log) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
    }
    
    static func getFile(exceptionIn: ExceptionInfo?) -> MultipartFile? {
        guard exceptionIn != nil else {
            return nil
        }
        
        let fileName = CrashHandler.generateLogFileName()
        let mimeType = "text/plain"
        
        if let content = exceptionIn?.crashLogFile {
            return MultipartFile(fileName: fileName, mimeType: mimeType, data: Data(content.utf8))
        }
        
        return MultipartFile(fileName: fileName, mimeType: mimeType, data: Data("".utf8))
    }
    
    
    private static func sendOrSaveLogEvent(_ logEntity: LogEntity, completion: (@Sendable (Error?) -> Void)? = nil) {
        let localLogEntity = logEntity
        let localTag = tag
        
        let workItem = DispatchWorkItem {
            let apiService = ServiceContainer.shared.apiService
            
            let endpointLog = Log()
            endpointLog.appVersion = localLogEntity.appVersion
            endpointLog.classFQN = localLogEntity.classFQN
            endpointLog.fileName = localLogEntity.fileName
            endpointLog.lineNumber = localLogEntity.lineNumber
            endpointLog.message = localLogEntity.message
            endpointLog.stackTrace = localLogEntity.stackTrace
            endpointLog.context = localLogEntity.context
            endpointLog.type = localLogEntity.type
            endpointLog.file = localLogEntity.file
            
            let logEndpoint = LogEndpoint(log: endpointLog)
            
            apiService.executeRequest(logEndpoint, responseType: LogResponse.self) { (result: ApiResult<LogResponse>) in
                handleLogRequestResult(
                    result: result,
                    logEntity: localLogEntity,
                    tag: localTag,
                    completion: completion
                )
            }
        }
        
        queue.async(execute: workItem)
    }

    private static func handleLogRequestResult(
        result: ApiResult<LogResponse>,
        logEntity: LogEntity,
        tag: String,
        completion: (@Sendable (Error?) -> Void)?
    ) {
        if result.errorType == .none {
            debugPrint("\(tag): Log sent successfully")
            DispatchQueue.main.async {
                completion?(nil)
            }
        } else {
            let error = AppAmbitLogger.buildError(message: result.message ?? "Unknown error", code: 101)
            AppAmbitLogger.log(message: "Log send failed: \(result.message ?? "")")
            
            storeLogInDb(logEntity) { dbError in
                DispatchQueue.main.async {
                    if let dbError = dbError {
                        let message = "Failed to store log: \(dbError.localizedDescription)"
                        AppAmbitLogger.log(message: message, context: tag)
                    } else {
                        debugPrint("\(tag): Log stored in database as fallback")
                    }
                    completion?(error)
                }
            }
        }
    }

    private static func storeLogInDb(_ log: LogEntity, completion: (@Sendable (Error?) -> Void)? = nil) {
        let workItem = DispatchWorkItem {
            do {
                let storable: StorageService = ServiceContainer.shared.storageService
                try storable.putLogEvent(log)
                DispatchQueue.main.async {
                    completion?(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(error)
                }
            }
        }
        queue.async(execute: workItem)
    }
}
