import Foundation
import UIKit

final class AppAmbitInfoService: AppInfoService {
    let appVersion:  String?
    let build:       String?
    var platform:    String? { "iOS" }
    var os:          String? { Self.currentOSVersion() }
    let deviceModel: String?
    let country:     String?
    let utcOffset:   String?
    let language:    String?

    init() {
        let bundle = Bundle.main
        self.appVersion  = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        self.build       = bundle.object(forInfoDictionaryKey: "CFBundleVersion")              as? String ?? "Unknown"
        self.deviceModel = Self.getDeviceModelIdentifier()

        let locale = Locale.current
        self.country   = locale.regionCode  ?? "Unknown"
        self.language  = locale.languageCode ?? "Unknown"
        

        let tz   = TimeZone.current
        let secs = tz.secondsFromGMT()
        let hrs  = secs / 3600
        let mins = abs(secs / 60) % 60
        self.utcOffset = String(format: "%+03d:%02d", hrs, mins)
    }

    private static func currentOSVersion() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static func getDeviceModelIdentifier() -> String {
        if let sysctlValue = sysctlString(for: "hw.machine"), !sysctlValue.isEmpty {
            return sysctlValue
        }

        var info = utsname()
        uname(&info)
        let machineMirror = Mirror(reflecting: info.machine)
        let identifier = machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }

        return identifier.isEmpty ? "Unknown" : identifier
    }

    private static func sysctlString(for name: String) -> String? {
        var size: size_t = 0
        if sysctlbyname(name, nil, &size, nil, 0) != 0 || size == 0 {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: Int(size))
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctlbyname(name, ptr.baseAddress, &size, nil, 0)
        }
        if result != 0 {
            return nil
        }

        return String(cString: buffer)
    }
}
