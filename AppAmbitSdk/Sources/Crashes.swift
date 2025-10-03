import Foundation
import UIKit


@objcMembers
public final class Crashes: NSObject, @unchecked Sendable {
    
    // MARK: - Objective-C

    @preconcurrency
    @objc(logErrorWithMessage:completion:)
    public static func objc_logError(message: String,
                                     completion: (@Sendable () -> Void)?)
    {
        self.logError(message: message,
                      properties: nil,
                      classFqn: nil,
                      exception: nil,
                      fileName: nil,
                      lineNumber: #line) { _ in
            if let completion { DispatchQueue.main.async { completion() } }
        }
    }

    @preconcurrency
    @objc(logErrorWithMessage:properties:completion:)
    public static func objc_logError(message: String,
                                     properties: [String: String]?,
                                     completion: (@Sendable () -> Void)?)
    {
        self.logError(message: message,
                      properties: properties,
                      classFqn: nil,
                      exception: nil,
                      fileName: nil,
                      lineNumber: #line) { _ in
            if let completion { DispatchQueue.main.async { completion() } }
        }
    }

    @preconcurrency
    @objc(logErrorWithMessage:properties:classFqn:completion:)
    public static func objc_logError(message: String,
                                     properties: [String: String]?,
                                     classFqn: String?,
                                     completion: (@Sendable () -> Void)?)
    {
        self.logError(message: message,
                      properties: properties,
                      classFqn: classFqn,
                      exception: nil,
                      fileName: nil,
                      lineNumber: #line) { _ in
            if let completion { DispatchQueue.main.async { completion() } }
        }
    }

    @preconcurrency
    @objc(logErrorWithNSException:properties:classFqn:completion:)
    public static func objc_logError(nsException: NSException,
                                     properties: [String: String]?,
                                     classFqn: String?,
                                     completion: (@Sendable () -> Void)?)
    {
        self.logError(nsException: nsException,
                      properties: properties,
                      classFqn: classFqn,
                      fileName: nil,
                      lineNumber: #line) { _ in
            if let completion { DispatchQueue.main.async { completion() } }
        }
    }

    
    // MARK: - Singleton
    public static let shared = Crashes()

    // MARK: - Servicios
    private var apiService: ApiService?
    private var storageService: StorageService?

    // MARK: - State
    private var isLoadingCrashes = false

    private var isSendingBatch = false
    private var batchWaiters: [(@Sendable (Error?) -> Void)] = []
    private var batchTimeoutTimer: DispatchSourceTimer?
    private static let batchTimeoutSeconds: Int = 30

    // MARK: - Init
    private override init() {
        self.apiService = ServiceContainer.shared.apiService
        self.storageService = ServiceContainer.shared.storageService
        super.init()
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
            DispatchQueue.main.async { completion(isCrash) }
        }
    }
    
    public static func generateTestCrash() {
        do { throw NSError(domain: "DataStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "some crash"]) }
        catch { fatalError("An error was thrown: \(error.localizedDescription)") }
    }
    
    
    // MARK: - Overload for NSError
    public static func logError(
        nsError: NSError,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        fileName: String? = nil,
        lineNumber: Int64 = #line,
        completion: (@Sendable (NSError?) -> Void)? = nil
    ) {
        let cb: (@Sendable (NSError?) -> Void)? = completion

        self.logError(
            exception: nsError,
            properties: properties,
            classFqn: classFqn,
            fileName: fileName,
            lineNumber: lineNumber,
            completion: { err in
                cb?(err as NSError?)
            }
        )
    }
    
    public static func logError(
        nsException: NSException,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        fileName: String? = nil,
        lineNumber: Int64 = #line,
        completion: (@Sendable (NSError?) -> Void)? = nil
    ) {
        var userInfo: [String: Any] = [:]
        if let reason = nsException.reason { userInfo[NSLocalizedDescriptionKey] = reason }
        if let info = nsException.userInfo { userInfo["NSExceptionUserInfo"] = info }
        userInfo["NSExceptionName"] = nsException.name.rawValue

        let bridged = NSError(domain: nsException.name.rawValue, code: 0, userInfo: userInfo)
        let cb: (@Sendable (NSError?) -> Void)? = completion

        self.logError(
            exception: bridged,
            properties: properties,
            classFqn: classFqn,
            fileName: fileName,
            lineNumber: lineNumber,
            completion: { err in
                cb?(err as NSError?)
            }
        )
    }

    public static func logError(
        exception: Error? = nil,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        fileName: String? = #file,
        lineNumber: Int64 = #line,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        Queues.crashFiles.async {
            func callLogEvent(with className: String?) {
                Logging.logEvent(
                    message: nil,
                    logType: .error,
                    exception: exception,
                    properties: properties,
                    classFqn: className,
                    fileName: fileName,
                    lineNumber: lineNumber,
                    completion: completion
                )
            }
            if let classFqn { callLogEvent(with: classFqn) }
            else if let caller = StackUtils.getCallerClassName() { callLogEvent(with: caller) }
            else { callLogEvent(with: nil) }
        }
    }

    public static func logError(
        message: String,
        properties: [String: String]? = nil,
        classFqn: String? = nil,
        exception: Error? = nil,
        fileName: String? = #file,
        lineNumber: Int64 = #line,
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        Queues.crashFiles.async {
            func callLogEvent(with className: String?) {
                Logging.logEvent(
                    message: message,
                    logType: .error,
                    exception: exception,
                    properties: properties,
                    classFqn: className,
                    fileName: fileName,
                    lineNumber: lineNumber,
                    completion: completion
                )
            }
            if let classFqn { callLogEvent(with: classFqn) }
            else if let caller = StackUtils.getCallerClassName() { callLogEvent(with: caller) }
            else { callLogEvent(with: nil) }
        }
    }
    
    func loadCrashFileIfExists(completion: (@Sendable (Error?) -> Void)? = nil) {
        Queues.crashFiles.async {
            guard !self.isLoadingCrashes else {
                completion?(AppAmbitLogger.buildError(message: "Already processing crash files"))
                return
            }
            self.isLoadingCrashes = true
            let release: @Sendable () -> Void = {
                Queues.crashFiles.async { self.isLoadingCrashes = false }
            }

            guard SessionManager.isSessionActive else {
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

            AppAmbitLogger.log(message: "Processing \(crashFilesCount) crash file(s)")
            CrashHandler.setCrashFlag(true)

            if crashFilesCount == 1 {
                let exceptionInfo = crashesFiles[0]
                Self.logCrash(exceptionInfo: exceptionInfo) { _ in
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

    static func sendBatchLogs(completion: (@Sendable (Error?) -> Void)? = nil) {
        let finishOnBatch: (@Sendable (Error?) -> Void) = { err in
            Queues.batch.async {
                shared.isSendingBatch = false
                if let t = shared.batchTimeoutTimer { t.cancel() }
                shared.batchTimeoutTimer = nil

                let cbs = shared.batchWaiters
                shared.batchWaiters.removeAll()

                for cb in cbs { DispatchQueue.global(qos: .utility).async { cb(err) } }
            }
        }

        Queues.batch.async {
            if let completion { shared.batchWaiters.append(completion) }

            guard !shared.isSendingBatch else {
                AppAmbitLogger.log(message: "SendBatchLogs skipped: already in progress")
                return
            }
            shared.isSendingBatch = true

            let timer = DispatchSource.makeTimerSource(queue: Queues.batch)
            timer.schedule(deadline: .now() + .seconds(batchTimeoutSeconds))
            timer.setEventHandler {
                AppAmbitLogger.log(message: "SendBatchLogs timeout: releasing gate")
                finishOnBatch(AppAmbitLogger.buildError(message: "SendBatchLogs timeout"))
            }
            shared.batchTimeoutTimer = timer
            timer.resume()

            Self.getLogsInDbAsync { logs, error in
                Queues.batch.async {
                    if let error = error {
                        AppAmbitLogger.log(message: "Error getting logs: \(error.localizedDescription)")
                        finishOnBatch(error)
                        return
                    }
                    guard let logs = logs, !logs.isEmpty else {
                        AppAmbitLogger.log(message: "There are no logs to send")
                        finishOnBatch(nil)
                        return
                    }

                    let logBatch = LogBatch(logs: logs)
                    let endpoint = LogBatchEndpoint(logBatch: logBatch)

                    shared.apiService?.executeRequest(endpoint, responseType: BatchResponse.self) { response in

                        Queues.batch.async {
                            if response.errorType != .none {
                                AppAmbitLogger.log(message: "Logs were not sent: \(response.message ?? "")")
                                finishOnBatch(AppAmbitLogger.buildError(message: response.message ?? "Unknown error"))
                                return
                            }

                            do {
                                try shared.storageService?.deleteLogList(logs)
                                AppAmbitLogger.log(message: "SendBatchLogs successfully sent")
                                finishOnBatch(nil)
                            } catch {
                                AppAmbitLogger.log(message: "Failed deleting logs: \(error.localizedDescription)")
                                finishOnBatch(error)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Privates (helpers)

    private static func logCrash(exceptionInfo: ExceptionInfo, completion: (@Sendable (Error?) -> Void)? = nil) {
        Logging.logEvent(
            message: exceptionInfo.message,
            logType: .crash,
            exceptionInfo: exceptionInfo,
            properties: nil,
            classFqn: exceptionInfo.classFullName,
            fileName: exceptionInfo.fileNameFromStackTrace,
            lineNumber: exceptionInfo.lineNumberFromStackTrace,
            completion: completion
        )
    }

    private static func getLogsInDbAsync(_ completion: @escaping @Sendable (_ logs: [LogEntity]?, _ error: Error?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let logs = try shared.storageService?.getOldest100Logs()
                completion(logs, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
    }
    
    private func storeBatchCrashesLog(files: [ExceptionInfo]) {
        let storable = ServiceContainer.shared.storageService
        for crash in files {
            let logEntity = mapExceptionInfoLogEntity(exceptionInfo: crash)
            do { try storable.putLogEvent(logEntity) }
            catch { AppAmbitLogger.log(message: "Error save file crash: \(error.localizedDescription)") }
        }
    }

    private func mapExceptionInfoLogEntity(exceptionInfo: ExceptionInfo) -> LogEntity {
        let stackTrace = !exceptionInfo.stackTrace.isEmpty
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
}
