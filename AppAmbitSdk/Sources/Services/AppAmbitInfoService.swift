import Foundation

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
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        return mirror.children.compactMap { element in
            guard let value = element.value as? Int8, value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }.joined()
    }
}
