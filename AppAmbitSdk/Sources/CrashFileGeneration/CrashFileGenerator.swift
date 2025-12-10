import Foundation

final class CrashFileGenerator {

    static func generateCrashLog(exception: NSException?, stackTrace: String?, error: Error?) -> String {
        var log = ""
        let services = ServiceContainer.shared
        let appInfo = services.appInfoService

        do {
            let deviceId = try services.storageService.getDeviceId()
            addHeader(to: &log, appInfo: appInfo, deviceId: deviceId)
        } catch {
            addHeader(to: &log, appInfo: appInfo, deviceId: nil)
            log += "\nError getting deviceId: \(error.localizedDescription)\n"
        }

        log += "\n"
        log += "iOS Exception Stack:\n"

        if let ex = exception {
            log += ex.callStackSymbols.joined(separator: "\n")
            log += "\n"
        }

        if let st = stackTrace, !st.isEmpty {
            log += st
            log += "\n"
        }

        if error != nil {
            log += Thread.callStackSymbols.joined(separator: "\n")
            log += "\n"
        }

        log += "\n\n"
        addFrames(to: &log)
        return log
    }

    private static func addHeader(to log: inout String, appInfo: AppInfoService, deviceId: String?) {
        log += "Package: \(Bundle.main.bundleIdentifier ?? "Unknown")\n"
        log += "Version Code: \(appInfo.build ?? "Unknown")\n"
        log += "Version Name: \(appInfo.appVersion ?? "Unknown")\n"
        log += "Manufacturer: Apple\n"
        log += "iOS: \(appInfo.os ?? "Unknown")\n"
        log += "Model: \(appInfo.deviceModel ?? "Unknown")\n"
        log += "Device Id: \(deviceId ?? "Unknown")\n"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        log += "Date: \(formatter.string(from: Date()))\n"
    }

    private static func addFrames(to log: inout String) {
        let frames = Thread.callStackSymbols
        log += "Backtrace (current thread):\n"
        for (index, frame) in frames.enumerated() {
            log += "  Frame \(index): \(frame)\n"
        }
        log += "\n"
    }
}
