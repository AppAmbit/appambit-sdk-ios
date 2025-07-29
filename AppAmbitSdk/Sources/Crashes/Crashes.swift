import Foundation

public class Crashes: @unchecked Sendable {
    // MARK: - State
    private let workQueue = DispatchQueue(label: "com.appambit.crashes.queue", attributes: .concurrent)
    private static let logErrorQueue = DispatchQueue(label: "com.appambit.crashes.queue", attributes: .concurrent)
    private var crashStorageURL: URL?
    
    // MARK: - Singleton
    static let shared = Crashes()
    private init() {}
    
    private static func logCrash(exceptionInfo: ExceptionInfo, completion: (@Sendable (Error?) -> Void)? = nil) {
        
        Logging.logEvent(message: exceptionInfo.message,
                         logType: LogType.crash,
                         exceptionInfo: exceptionInfo,
                         properties: nil, classFqn: exceptionInfo.classFullName, fileName: exceptionInfo.fileNameFromStackTrace, lineNumber: exceptionInfo.lineNumberFromStackTrace, createdAt: exceptionInfo.createdAt, completion: completion )
    }
    
    public static func didCrashInLastSession(completion: @escaping @Sendable (Bool) -> Void) {
        CrashHandler.shared.didAppCrashFileExist { result in
            let isCrash: Bool
            
            switch result {
            case .success(let didCrash):
                isCrash = didCrash
            case .failure(let error):
                AppAmbitLogger.log(message: "Error checking crash: \(error.localizedDescription)")
                isCrash = false
            }
            
            DispatchQueue.main.async {
                completion(isCrash)
            }
        }
    }
    
    public static func generateTestCrash() {
        do {
            throw NSError(domain: "DataStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "some crash"])
        } catch {
            fatalError("An error was thrown: \(error.localizedDescription)")
        }
    }
    
    public static func logError(
        exception: Error? = nil,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        fileName: String? = #file,
        lineNumber: Int64 = #line,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let workItem = DispatchWorkItem {
            func callLogEvent(with className: String?) {
                Logging.logEvent(
                    message: nil,
                    logType: .error,
                    exception: exception,
                    properties: properties,
                    classFqn: className,
                    fileName: fileName,
                    lineNumber: lineNumber,
                    createdAt: nil,
                    completion: completion
                )
            }
            
            if let classFqn = classFqn {
                callLogEvent(with: classFqn)
            } else {
                
                if let caller = StackUtils.getCallerClassName() {
                    callLogEvent(with: caller)
                        }
            }
        }
        
        logErrorQueue.async(execute: workItem)
    }
    
    public static func logError(
        message: String,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        exception: Error? = nil,
        fileName: String? = #file,
        lineNumber: Int64 = #line,
        createdAt: Date? = nil,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        let workItem = DispatchWorkItem {
            func callLogEvent(with className: String?) {
                Logging.logEvent(
                    message: message,
                    logType: .error,
                    exception: exception,
                    properties: properties,
                    classFqn: className,
                    fileName: fileName,
                    lineNumber: lineNumber,
                    createdAt: createdAt,
                    completion: completion
                )
            }
            
            if let classFqn = classFqn {
                callLogEvent(with: classFqn)
            } else {
       
                
                if let caller = StackUtils.getCallerClassName() {
                    callLogEvent(with: caller)
                        }
            }
        }
        
        logErrorQueue.async(execute: workItem)
    }
    
    
    internal func loadCrashFileIfExists() {
        let workItem = DispatchWorkItem {
            
            if !SessionManager.isSessionActive {
                 AppAmbitLogger.log(message: "There is no active session")
                 return
             }
            
            let crashesFiles = CrashHandler.shared.loadCrashInfos()
            let crashFilesCount = crashesFiles.count
            
            guard crashFilesCount > 0 else {
                CrashHandler.setCrashFlag(false)
                return
            }
            
            debugPrint("Processing \(crashFilesCount) crash file(s)")
            CrashHandler.setCrashFlag(true)
            
            if crashFilesCount == 1 {
                let exceptionInfo = crashesFiles[0]
                Crashes.logCrash(exceptionInfo: exceptionInfo) { error in
                    if let error = error {
                        debugPrint("Error logging crash: \(error.localizedDescription)")
                    }
                    CrashHandler.shared.clearCrashLogs()
                }
            } else {
                self.storeBatchCrashesLog(files: crashesFiles)
                CrashHandler.shared.clearCrashLogs()
            }
        }
        workQueue.async(execute: workItem)
    }
    
    private func storeBatchCrashesLog(files:[ExceptionInfo]) {
        let storable = ServiceContainer.shared.storageService
        for crash in files {
            let logEntity = mapExceptionInfoLogEntity(exceptionInfo: crash)
            do {
                try storable.putLogEvent(logEntity)
            } catch {
                debugPrint("Error save file crasg: \(error.localizedDescription)")
            }
        }
    }
    
    private func mapExceptionInfoLogEntity(exceptionInfo: ExceptionInfo) -> LogEntity {
        
        let stackTrace = exceptionInfo.stackTrace.isEmpty
        ? exceptionInfo.stackTrace
        : AppConstants.noStackTraceAvailable
        
        let version = ServiceContainer.shared.appInfoService.appVersion ?? ""
        let build = ServiceContainer.shared.appInfoService.build ?? ""
        let appVersionInfo = "\(version) (\(build))"
                
        let log = LogEntity()
        log.id = UUID().uuidString
        log.appVersion = appVersionInfo
        log.classFQN = (exceptionInfo.classFullName == "" ? AppConstants.unknownClass : exceptionInfo.classFullName)
        log.fileName = exceptionInfo.fileNameFromStackTrace == "" ? AppConstants.unknownFileName : exceptionInfo.fileNameFromStackTrace
        log.lineNumber = exceptionInfo.lineNumberFromStackTrace
        log.message = exceptionInfo.message ?? ""
        log.stackTrace = stackTrace
        log.context = [
            "Source": exceptionInfo.source ?? "",
            "InnerException": exceptionInfo.innerException ?? ""
        ]
        log.type = .crash
        log.file = Logging.getFile(exceptionIn: exceptionInfo)
        log.createdAt = exceptionInfo.createdAt
        
        return log
    }
}
