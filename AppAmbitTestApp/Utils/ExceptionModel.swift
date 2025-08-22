import Foundation
import Darwin

public struct ExceptionModel: Codable {
    public let type: String
    public let sessionId: String
    public let message: String?
    public let stackTrace: String
    public let source: String?
    public let innerException: String?
    public let fileNameFromStackTrace: String
    public let classFullName: String
    public let lineNumberFromStackTrace: Int64
    public var crashLogFile: String?
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case type = "Type"
        case sessionId = "SessionId"
        case message = "Message"
        case stackTrace = "StackTrace"
        case source = "Source"
        case innerException = "InnerException"
        case fileNameFromStackTrace = "FileNameFromStackTrace"
        case classFullName = "ClassFullName"
        case lineNumberFromStackTrace = "LineNumberFromStackTrace"
        case crashLogFile = "CrashLogFile"
        case createdAt = "CreatedAt"
    }

    public static func fromError(_ error: Error, sessionId: String, deviceId: String? = nil, now: Date = Date()) -> ExceptionModel {
        let nsError = error as NSError
        let stackTraceArray = Thread.callStackSymbols
        let backtraceString = stackTraceArray.joined(separator: "\n")

        let (fileName, className, lineNumber) = parseStackTrace(stackTraceArray)

        let inner = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError).map { String(describing: $0) }

        let source = stackTraceArray.first.flatMap { line -> String? in
            let components = line.split(separator: " ")
            return (components.count > 1) ? String(components[1]) : nil
        }

        return ExceptionModel(
            type: nsError.domain,
            sessionId: sessionId,
            message: nsError.localizedDescription,
            stackTrace: backtraceString,
            source: source,
            innerException: inner,
            fileNameFromStackTrace: fileName ?? "UnknownFile",
            classFullName: className ?? "UnknownClass",
            lineNumberFromStackTrace: lineNumber ?? 0,
            crashLogFile: generateCrashLog(exception: nil, stackTrace: backtraceString, error: error, deviceId: deviceId, now: now),
            createdAt: now
        )
    }

    private static func parseStackTrace(_ stackTrace: [String]) -> (String?, String?, Int64?) {
        for symbol in stackTrace {
            if let range = symbol.range(of: ".swift:"),
               let fileStart = symbol[..<range.lowerBound].lastIndex(of: "/") {
                let fileName = String(symbol[symbol.index(after: fileStart)..<range.upperBound])
                let className = fileName.replacingOccurrences(of: ".swift", with: "")
                let afterFile = symbol[range.upperBound...]
                let lineNumberString = afterFile.prefix { $0.isNumber }
                if let lineNumber = Int64(lineNumberString) {
                    return (fileName, className, lineNumber)
                }
            }
        }
        return (nil, nil, nil)
    }

    public static func generateCrashLog(
        exception: NSException?,
        stackTrace: String?,
        error: Error?,
        deviceId: String? = nil,
        now: Date = Date()
    ) -> String {
        let app = collectAppInfo()
        let log = NSMutableString()

        addHeader(to: log, appInfo: app, deviceId: deviceId, now: now)

        log.append("\n")
        log.append("iOS Exception Stack:\n")
        if let exception = exception {
            log.append(exception.callStackSymbols.joined(separator: "\n"))
        }
        if let stackTrace = stackTrace, !stackTrace.isEmpty {
            log.append("\n\(stackTrace)\n")
        }
        if error != nil {
            let symbols = Thread.callStackSymbols.joined(separator: "\n")
            log.append("\n\(symbols)\n")
        }

        log.append("\n\n")
        addSymbols(to: log)

        return log as String
    }

    private struct AppInfo {
        let bundleId: String
        let build: String
        let appVersion: String
        let os: String
        let deviceModel: String
    }

    private static func collectAppInfo() -> AppInfo {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]
        let bundleId = bundle.bundleIdentifier ?? "Unknown"
        let build = (info["CFBundleVersion"] as? String) ?? "Unknown"
        let appVersion = (info["CFBundleShortVersionString"] as? String) ?? "Unknown"

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let os = "iOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        let deviceModel = sysctlString(for: "hw.machine") ?? "Unknown"

        return AppInfo(bundleId: bundleId, build: build, appVersion: appVersion, os: os, deviceModel: deviceModel)
    }

    private static func sysctlString(for name: String) -> String? {
        var size: size_t = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: Int(size))
        let result = sysctlbyname(name, &value, &size, nil, 0)
        if result == 0 {
            return String(cString: value)
        }
        return nil
    }

    private static func addHeader(to log: NSMutableString, appInfo: AppInfo, deviceId: String?, now: Date) {
        log.append("Package: \(appInfo.bundleId)\n")
        log.append("Version Code: \(appInfo.build)\n")
        log.append("Version Name: \(appInfo.appVersion)\n")
        log.append("Manufacturer: Apple\n")
        log.append("iOS: \(appInfo.os)\n")
        log.append("Model: \(appInfo.deviceModel)\n")
        log.append("Device Id: \(deviceId ?? "Unknown")\n")

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        log.append("Date: \(formatter.string(from: now))\n")
    }

    private static func addSymbols(to log: NSMutableString) {
        let symbolsString = Thread.callStackSymbols
        for (index, symbol) in symbolsString.enumerated() {
            log.append("Thread \(index):\n")
            log.append("  \(symbol)\n\n")
        }
    }
}
