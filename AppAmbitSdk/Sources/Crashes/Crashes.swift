import Foundation

public class Crashes: @unchecked Sendable {
    // MARK: - State
    private let workQueue = DispatchQueue(label: "com.appambit.crashes.queue", attributes: .concurrent)
    private var crashStorageURL: URL?
    
    // MARK: - Singleton
    static let shared = Crashes()
    private init() {}
    
    private static func logCrash(exceptionInfo: ExceptionInfo) {
        
        Logging.logEvent(message: exceptionInfo.message,
                         logType: LogType.crash,
                         exceptionInfo: exceptionInfo,
                         properties: nil, classFqn: exceptionInfo.classFullName, fileName: exceptionInfo.fileNameFromStackTrace, lineNumber: exceptionInfo.lineNumberFromStackTrace, createdAt: exceptionInfo.createdAt)
    }
    
    public static func didCrashInLastSession() -> Bool {
        return CrashHandler.shared.didAppCrashFileExist()
    }
    
    public static func generateTestCrash() {
        do {
            throw NSError(domain: "DataStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "some crash"])
        } catch {
            fatalError("An error was thrown: \(error.localizedDescription)")
        }
    }
    
    func loadCrashFileIfExists() {
        workQueue.async {
            let crashesFiles = CrashHandler.shared.loadCrashInfos()
            
            let crashFilesCount = crashesFiles.count
            
            if crashFilesCount == 0 {
                CrashHandler.setCrashFlag(false)
                return
            }
            
            debugPrint("Sending \(crashFilesCount) crash(es)");
            CrashHandler.setCrashFlag(true)
            
            if crashFilesCount == 1 {
                let exceptionInfo = crashesFiles[0]
                Crashes.logCrash(exceptionInfo: exceptionInfo)
                CrashHandler.shared.clearCrashLogs()
            }
        
            if crashFilesCount > 1 {
                self.storeBatchCrashesLog(files: crashesFiles)
                CrashHandler.shared.clearCrashLogs()
            }
        }
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
