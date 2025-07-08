import Foundation

public struct DateUtils {
    public static var utcNow: Date {
        Date()
    }
    
    public static var utcNowFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.string(from: Date())
    }
}
