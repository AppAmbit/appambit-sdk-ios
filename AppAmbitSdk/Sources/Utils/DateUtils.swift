import Foundation

struct DateUtils {
    private init() {}
    private static let formatterQueue = DispatchQueue(label: "com.appambit.dateFormatterQueue")

    /// Formatter for "yyyy-MM-dd'T'HH:mm:ssZ" (ISO 8601)
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f
    }()

    /// Formatter for "yyyy-MM-dd HH:mm:ss" (custom)
    private static let customFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
   
     private static var iso8601FullFormatter: ISO8601DateFormatter {
         formatterQueue.sync {
             let f = ISO8601DateFormatter()
             f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
             return f
         }
     }


    static var utcNow: Date {
        Date()
    }

    static func utcIsoFormatString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func utcIsoFormatDate(from string: String) -> Date? {
        isoFormatter.date(from: string)
    }

    static func utcCustomFormatString(from date: Date) -> String {
        customFormatter.string(from: date)
    }

    static func utcCustomFormatDate(from string: String) -> Date? {
        customFormatter.date(from: string)
    }
    
    static func utcIso8601FullFormatString(from date: Date) -> String {
        iso8601FullFormatter.string(from: date)
    }

    static func utcIso8601FullFormatDate(from string: String) -> Date? {
        iso8601FullFormatter.date(from: string)
    }
}
