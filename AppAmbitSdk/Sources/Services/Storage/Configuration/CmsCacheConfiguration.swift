import Foundation

struct CmsCacheConfiguration {
    private init() {}

    static let tableName = "cms_cache"

    public enum Column: String, CaseIterable {
        case contentType = "ContentType"
        case jsonData = "JsonData"
        case lastUpdated = "LastUpdated"

        public var name: String { rawValue }
    }

    static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.contentType.name) TEXT PRIMARY KEY,
            \(Column.jsonData.name) TEXT,
            \(Column.lastUpdated.name) DATETIME
        );
        """
    }
}
