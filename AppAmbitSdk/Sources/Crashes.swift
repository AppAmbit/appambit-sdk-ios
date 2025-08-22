import Foundation

public final class Crashes: @unchecked Sendable {
    private var apiService: ApiService?
    private var storageService: StorageService?
    private var crashStorageURL: URL?
    private let workQueue = DispatchQueue(label: "com.appambit.crashes.queue", attributes: .concurrent)
    private static let logErrorQueue = DispatchQueue(label: "com.appambit.crashes.queue", attributes: .concurrent)
    private static let syncQueueBatch = DispatchQueue(label: "com.appambit.crashes.batch", attributes: .concurrent)
    private var isSendingBatch = false
    private static let batchLock = NSLock()
    private static let batchSendTimeout: TimeInterval = 30
    private static let sendingGate = DispatchSemaphore(value: 1)


    static let shared = Crashes()
    private init() {
        apiService = ServiceContainer.shared.apiService
        storageService = ServiceContainer.shared.storageService
    }

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
    
    func loadCrashFileIfExists(completion: (@Sendable (Error?) -> Void)? = nil) {
        workQueue.async {
            Crashes.sendingGate.wait()
            let release: @Sendable () -> Void = { Crashes.sendingGate.signal() }

            if !SessionManager.isSessionActive {
                AppAmbitLogger.log(message: "There is no active session")
                completion?(AppAmbitLogger.buildError(message: "There is no active session"))
                release()
                return
            }

            let crashesFiles = CrashHandler.shared.loadCrashInfos()
            let crashFilesCount = crashesFiles.count

            guard crashFilesCount > 0 else {
                CrashHandler.setCrashFlag(false)
                completion?(nil)
                release()
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
                    completion?(nil)
                    release()
                }
            } else {
                self.storeBatchCrashesLog(files: crashesFiles)
                CrashHandler.shared.clearCrashLogs()
                completion?(nil)
                release()
            }
        }
    }
    
    static func sendBatchLogs(completion: (@Sendable () -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            Crashes.sendingGate.wait()
            let release: @Sendable () -> Void = {
                Crashes.sendingGate.signal()
                completion?()
            }

            getLogsInDb { logs, error in
                if let error = error {
                    AppAmbitLogger.log(message: "Error getting logs: \(error.localizedDescription)")
                    release()
                    return
                }

                guard let logs = logs, !logs.isEmpty else {
                    AppAmbitLogger.log(message: "There are no logs to send")
                    release()
                    return
                }

                let logBatch = LogBatch(logs: logs)
                let logBatchEndpoint = LogBatchEndpoint(logBatch: logBatch)

                shared.apiService?.executeRequest(logBatchEndpoint, responseType: BatchResponse.self) { response in
                    defer { release() }

                    if response.errorType != .none {
                        AppAmbitLogger.log(message: "Logs were not sent: \(response.message ?? "")")
                        return
                    }

                    AppAmbitLogger.log(message: "Logs sent successfully")
                    do {
                        try shared.storageService?.deleteLogList(logs)
                    } catch {
                        AppAmbitLogger.log(message: error.localizedDescription)
                    }
                }
            }
        }
    }


    private static func getLogsInDb(completion: @escaping @Sendable (_ logs: [LogEntity]?, _ error: Error?) -> Void) {
        syncQueueBatch.async {
            do {
                let logs = try shared.storageService?.getOldest100Logs()
                completion(logs, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
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
        log.sessionId = exceptionInfo.sessionId
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
    
    private static func withBatchLock<T>(_ body: () -> T) -> T {
        batchLock.lock(); defer { batchLock.unlock() }
        return body()
    }

    private static func getIsSending() -> Bool {
        withBatchLock { shared.isSendingBatch }
    }

    private static func setIsSending(_ v: Bool) {
        withBatchLock { shared.isSendingBatch = v }
    }

}
