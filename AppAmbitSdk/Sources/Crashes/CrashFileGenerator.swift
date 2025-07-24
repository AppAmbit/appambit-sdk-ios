import Foundation

final class CrashFileGenerator {
    
    static func generateCrashLog(exception: NSException?, stackTrace: String?, error: Error?) -> String {
        let log = NSMutableString()
        let services = ServiceContainer.shared
        let appInfo = services.appInfoService
    
        do {
            let deviceId = try services.storageService.getDeviceId()
            addHeader(to: log, appInfo: appInfo, deviceId: deviceId)
        } catch {
            addHeader(to: log, appInfo: appInfo, deviceId: nil)
            log.append("\nError getting deviceId: \(error.localizedDescription)\n")
        }
        
        log.append("\n")
        log.append("iOS Exception Stack:\n")
        if exception != nil {
            log.append(exception?.callStackSymbols.joined(separator: "\n") ?? "")
        }
        
        if stackTrace != nil {
            log.append("\(stackTrace ?? "")\n")
        }
        
        if let error = error {
            let symbols = Thread.callStackSymbols.joined(separator: "\n")
            log.append("\(symbols)\n")
        }
        
        log.append("\n\n")
    
        addThreads(to: log)
        
        return log as String
    }
    
    private static func addHeader(to log: NSMutableString, appInfo: AppInfoService, deviceId: String?) {
        log.append("Package: \(Bundle.main.bundleIdentifier ?? "Unknown")\n")
        log.append("Version Code: \(appInfo.build ?? "Unknown")\n")
        log.append("Version Name: \(appInfo.appVersion ?? "Unknown")\n")
        log.append("Manufacturer: Apple\n")
        log.append("iOS: \(appInfo.os ?? "Unknown")\n")
        log.append("Model: \(appInfo.deviceModel ?? "Unknown")\n")
        log.append("Device Id: \(deviceId ?? "Unknown")\n")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        log.append("Date: \(formatter.string(from: Date()))\n")
    }
    
    private static func addThreads(to log: NSMutableString) {
        let threadNames = Thread.callStackSymbols
        for (index, symbol) in threadNames.enumerated() {
            log.append("Thread \(index):\n")
            log.append("  \(symbol)\n\n")
        }
    }
}
