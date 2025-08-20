import Foundation
import Darwin


public class CrashHandler: @unchecked Sendable {
    // MARK: - Singleton
    static let shared = CrashHandler()
    
    // MARK: - Type Aliases
    private typealias ExceptionHandler = @convention(c) (NSException) -> Void
    
    // MARK: - State
    private let isolationQueue = DispatchQueue(label: "com.appambit.crashhandler.queue", attributes: .concurrent)
    private let filesQueue = DispatchQueue(label: "com.appambit.crashhandler.files", attributes: .concurrent)
    private var _previousHandler: ExceptionHandler?
    
    private var previousHandler: ExceptionHandler? {
        get { isolationQueue.sync { _previousHandler } }
        set { isolationQueue.async(flags: .barrier) { self._previousHandler = newValue } }
    }
    
    private var crashStorageURL: URL?
    
    private init() {
        if let crashLogsDir = CrashHandler.getCrashLogsDirectory() {
            self.crashStorageURL = crashLogsDir
            debugPrint("[CrashHandler] Crash log directory set to: \(crashLogsDir.path)")
        } else {
            debugPrint("[CrashHandler] ERROR: The crash log directory could not be determined or created.")
            self.crashStorageURL = nil
        }
    }
    
    func register() {
        debugPrint("[CrashHandler] Registering crash handlers...")
        setupExceptionHandler()
        setupSignalHandlers()
    }
    
    private func setupExceptionHandler() {
        previousHandler = NSGetUncaughtExceptionHandler()
        let newHandler: ExceptionHandler = { exception in
            debugPrint("[CrashHandler] NSException captured: \(exception.name.rawValue) - \(exception.reason ?? "No reason")")
            SessionManager.saveEndSessionToFile()
            let crashInfo = ExceptionInfo.fromNSException(exception)
            CrashHandler.shared.saveCrashInfo(crashInfo)
            
            NotificationCenter.default.post(
                name: .didCatchCrash,
                object: nil,
                userInfo: ["exceptionInfo": crashInfo]
            )
            
            CrashHandler.shared.previousHandler?(exception)
        }
        
        NSSetUncaughtExceptionHandler(newHandler)
        debugPrint("[CrashHandler] NSExceptionHandler configured.")
    }
    
    private func setupSignalHandlers() {
        let signals = [SIGABRT, SIGSEGV, SIGILL, SIGTRAP, SIGBUS, SIGPIPE, SIGSYS, SIGFPE]
        
        signals.forEach { sig in
            var action = sigaction()
            action.sa_flags = SA_SIGINFO
            action.__sigaction_u.__sa_sigaction = { (signal, info, context) in
                debugPrint("[CrashHandler] Signal \(signal) captured")
                SessionManager.saveEndSessionToFile()
                let backtraceSymbols = Thread.callStackSymbols
                let crashInfo = CrashHandler.shared.createSignalCrashInfo(
                    signal: signal,
                    stack: backtraceSymbols)
                
                CrashHandler.shared.saveCrashInfo(crashInfo)
                
                NotificationCenter.default.post(
                    name: .didCatchCrash,
                    object: nil,
                    userInfo: ["exceptionInfo": crashInfo]
                )
                
            
                var defaultAction = sigaction()
                sigaction(signal, nil, &defaultAction)
                defaultAction.__sigaction_u.__sa_handler = SIG_DFL
                sigaction(signal, &defaultAction, nil)
                kill(getpid(), signal)
            }
            sigaction(sig, &action, nil)
        }
        debugPrint("[CrashHandler] Signal Handlers configurados.")
    }
    
    // MARK: - Helpers
    private func createSignalCrashInfo(signal: Int32, stack: [String]) -> ExceptionInfo {
        let signalName: String
        switch signal {
        case SIGABRT: signalName = "SIGABRT"
        case SIGSEGV: signalName = "SIGSEGV"
        case SIGILL: signalName = "SIGILL"
        case SIGTRAP: signalName = "SIGTRAP"
        case SIGBUS: signalName = "SIGBUS"
        case SIGPIPE: signalName = "SIGPIPE"
        case SIGSYS: signalName = "SIGSYS"
        case SIGFPE: signalName = "SIGFPE"
        default: signalName = "Signal \(signal)"
        }
        
        let backtraceString: String = stack.joined(separator: "\n")
        let stackTraceElements = Self.parseStackTrace(backtraceString)
        
        return ExceptionInfo.fromSignalException (
            signalName: signalName,
            source: stack.first,
            stackTrace: backtraceString,
            fileNameFromStackTrace: stackTraceElements.first?.fileName ?? "",
            classFullName: stackTraceElements.first?.className ?? "",
            lineNumberFromStackTrace: stackTraceElements.first?.lineNumber ?? 0
        )
    }

    static func parseStackTrace(_ stackTrace: String) -> [(fileName: String?, className: String?, lineNumber: Int64?)] {
        var elements: [(fileName: String?, className: String?, lineNumber: Int64?)] = []
        let lines = stackTrace.split(separator: "\n")
        
        let symbolRegex = try? NSRegularExpression(pattern: "\\s+\\d+\\s+[^\\s]+\\s+([^\\s]+)\\s+\\+", options: [])
        
        for line in lines {
            let nsLine = line as NSString
            var fileName: String?
            var className: String?
            var lineNumber: Int64?

            if let match = symbolRegex?.firstMatch(in: String(line), options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if match.numberOfRanges > 1 {
                    let symbolRange = match.range(at: 1)
                    if symbolRange.location != NSNotFound {
                        let fullSymbol = nsLine.substring(with: symbolRange)
                        let parts = fullSymbol.split(separator: ".", maxSplits: 1)
                        
                        if parts.count > 0 {
                            if parts.count > 1 {
                                className = String(parts[0])
                            } else {
                                className = String(parts[0])
                            }
                        }
                    }
                }
            }

            let fileLineRegex = try? NSRegularExpression(pattern: "([^/]+(?:\\.swift|\\.m|\\.h)):(\\d+)", options: [])
            if let fileLineMatch = fileLineRegex?.firstMatch(in: String(line), options: [], range: NSRange(location: 0, length: nsLine.length)) {
                if fileLineMatch.numberOfRanges > 2 {
                    fileName = nsLine.substring(with: fileLineMatch.range(at: 1))
                    if let numStr = Int64(nsLine.substring(with: fileLineMatch.range(at: 2))) {
                        lineNumber = numStr
                    }
                }
            }
            elements.append((fileName: fileName, className: className, lineNumber: lineNumber))
        }
        return elements
    }
       
    fileprivate func saveCrashInfo(_ info: ExceptionInfo) {
        guard let crashStorageURL = crashStorageURL else {
            debugPrint("[CrashHandler] The crash storage URL could not be determined..")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: info.createdAt)
        let fileName = "crash_\(timestamp).json"
        let fileURL = crashStorageURL.appendingPathComponent(fileName)
        
        do {
            let encoder: JSONEncoder = {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601

                return encoder
            }()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(info)
            try data.write(to: fileURL, options: .atomic)
            debugPrint("[CrashHandler] Crash information saved in \(fileURL.lastPathComponent)")
        } catch {
            debugPrint("[CrashHandler] Error saving crash info: \(error.localizedDescription)")
        }
    }
    
    static func setCrashFlag(_ didCrash: Bool) {
        if didCrash {
            if !existCrashFlag() {
                createCrashFlagFile()
            }
        } else {
            if existCrashFlag() {
                clearCrashFlagFile()
            }
        }
    }
    
    private static func createCrashFlagFile() {
        guard let flagFileUrl = getCrashFlagFileUrl() else { return }
        
        do {
            try "".write(to: flagFileUrl, atomically: true, encoding: .utf8)
            debugPrint("[Crashes] Crash flag file created at: \(flagFileUrl.lastPathComponent)")
        } catch {
            debugPrint("[Crashes] ERROR creating crash flag file: \(error.localizedDescription)")
        }
    }
    
    private static func clearCrashFlagFile() {
        guard let flagFileUrl = getCrashFlagFileUrl() else { return }
        
        if FileManager.default.fileExists(atPath: flagFileUrl.path) {
            do {
                try FileManager.default.removeItem(at: flagFileUrl)
                debugPrint("[Crashes] Crash flag file cleared.")
            } catch {
                debugPrint("[Crashes] ERROR clearing crash flag file: \(error.localizedDescription)")
            }
        } else {
            debugPrint("[Crashes] Crash flag file does not exist, no need to clear.")
        }
    }
    
    private static func existCrashFlag() -> Bool {
        guard let flagFileUrl = getCrashFlagFileUrl() else { return false }
        let crashed = FileManager.default.fileExists(atPath: flagFileUrl.path)
        debugPrint("[Crashes] didCrashInLastSession: \(crashed ? "YES" : "NO")")
        return crashed
    }

    private static func getCrashFlagFileUrl() -> URL? {
        guard let crashLogsDir = getCrashLogsDirectory() else {
            return nil
        }
        return crashLogsDir.appendingPathComponent(AppConstants.didAppCrashFlagFileName)
    }
    
    public static func getCrashLogsDirectory() -> URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            debugPrint("[Crashes] ERROR: Could not find Application Support directory.")
            return nil
        }
        
        let crashLogsDir = appSupportDirectory.appendingPathComponent(AppConstants.crashLogsSubDirectory)
        
        do {
            if !FileManager.default.fileExists(atPath: crashLogsDir.path) {
                try FileManager.default.createDirectory(at: crashLogsDir, withIntermediateDirectories: true, attributes: nil)
                debugPrint("[Crashes] Crash log directory CREATED in: \(crashLogsDir.path)")
            }
            return crashLogsDir
        } catch {
            debugPrint("[Crashes] ERROR creating or verifying the crash logs directory: \(error.localizedDescription)")
            return nil
        }
    }

    func loadCrashInfos() -> [ExceptionInfo] {
        guard let crashStorageURL = crashStorageURL else { return [] }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: crashStorageURL, includingPropertiesForKeys: nil)
            
            let decoder: JSONDecoder = {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return decoder
            }()
            
            var loadedCrashes: [ExceptionInfo] = []

            for fileURL in fileURLs where
                fileURL.pathExtension == "json" &&
                fileURL.lastPathComponent.hasPrefix("crash_") {
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let crashInfo = try decoder.decode(ExceptionInfo.self, from: data)
                    loadedCrashes.append(crashInfo)
                } catch {
                    debugPrint("[CrashHandler] Error loading crash file \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }

            return loadedCrashes.sorted(by: { $0.createdAt < $1.createdAt })
        } catch {
            debugPrint("[CrashHandler] Error reading crashes directory: \(error.localizedDescription)")
            return []
        }
    }

    func clearCrashLogs() {
        guard let directory = crashStorageURL else {
            debugPrint("[CrashHandler] ERROR: crashStorageURL is nil")
            return
        }

        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let crashFiles = files.filter {
                $0.lastPathComponent.hasPrefix("crash_") && $0.pathExtension == "json"
            }

            for file in crashFiles {
                try fileManager.removeItem(at: file)
            }

            debugPrint("[CrashHandler] Debug: all crashes deleted from \(directory.path)")
        } catch {
            debugPrint("[CrashHandler] ERROR: Failed to delete crash files — \(error.localizedDescription)")
        }
    }

    static func generateLogFileName() -> String {
        let now = DateUtils.utcNow
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH_mm_ss_SSSZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let utcString = dateFormatter.string(from: now)
        let fileName = "log-\(utcString).txt"
        return fileName
    }
    
    func didAppCrashFileExist(completion: @escaping (@Sendable (Result<Bool, Error>) -> Void)) {
        let workItem = DispatchWorkItem {
            guard let directory = self.crashStorageURL else {
                let message = "[CrashHandler] ERROR: crashStorageURL is nil"
                
                AppAmbitLogger.log(message: message)
                return completion(.failure(AppAmbitLogger.buildError(message: message, code: 110)))
            }

            let fileURL = directory.appendingPathComponent(AppConstants.didAppCrashFlagFileName)

            let exists = FileManager.default.fileExists(atPath: fileURL.path)
            
            completion(.success(exists))
        }
        
        filesQueue.async(execute: workItem)
    }
}

// MARK: - Notification
extension Notification.Name {
    static let didCatchCrash = Notification.Name("didCatchCrashNotification")
}
