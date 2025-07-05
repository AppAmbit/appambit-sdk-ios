import Foundation
import UIKit

class DefaultAppInfoService: AppInfoService {
        
    var appVersion: String? { _appVersion }
    var build: String? { _buildNumber }
    var platform: String? { _platform }
    var os: String? { _osVersion }
    var deviceModel: String? { _deviceModel }
    var country: String? { _countryCode }
    var utcOffset: String? { _timeZoneOffset }
    var language: String? { _languageCode }
    var deviceName: String? { _deviceName }

    
    private let _appVersion: String
    private let _buildNumber: String
    private let _platform: String
    private let _osVersion: String
    private let _deviceModel: String
    private let _deviceName: String
    private let _countryCode: String
    private let _timeZoneOffset: String
    private let _languageCode: String
    
    
    init() {
        let bundle = Bundle.main
        _appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        _buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        _platform = "iOS"
        _deviceModel = Self.getDeviceModelIdentifier()
        
        let locale = Locale.current
        _countryCode = locale.regionCode ?? "Unknown"
        _languageCode = locale.languageCode ?? "Unknown"
        
        let timeZone = TimeZone.current
        let secondsFromGMT = timeZone.secondsFromGMT()
        let hours = secondsFromGMT / 3600
        let minutes = abs(secondsFromGMT / 60) % 60
        _timeZoneOffset = String(format: "%+03d:%02d", hours, minutes)
        
        let deviceInfo = Self.getDeviceInfoSafely()
        _osVersion = "\(deviceInfo.systemName) \(deviceInfo.systemVersion)"
        _deviceName = deviceInfo.name
    }
    
    
    private struct DeviceInfo {
        let systemName: String
        let systemVersion: String
        let name: String
    }
    
    private static func getDeviceInfoSafely() -> DeviceInfo {
        let semaphore = DispatchSemaphore(value: 0)
        
        var systemName = "iOS"
        var systemVersion = "Unknown"
        var name = "Unknown"
        
        DispatchQueue.main.async {
            let device = UIDevice.current
            systemName = device.systemName
            systemVersion = device.systemVersion
            name = device.name
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        return DeviceInfo(systemName: systemName, systemVersion: systemVersion, name: name)
    }
    
    private static func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
