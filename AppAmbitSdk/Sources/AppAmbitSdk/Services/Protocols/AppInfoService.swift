protocol AppInfoService {
    var appVersion: String?   { get }
    var build: String?        { get }
    var platform: String?     { get }
    var os: String?           { get }
    var deviceModel: String?  { get }
    var country: String?      { get }
    var utcOffset: String?    { get }
    var language: String?     { get }
    var deviceName: String?   { get }
}
