struct EventEntityConfiguration {
    private init() {}

    public static let tableName = "events"

    public enum Column: String {
        case id
        case sessionId
        case dataJson = "data_json"
        case name
        case createdAt

        public var name: String { rawValue }
    }

    public static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.id.name) TEXT PRIMARY KEY,
            \(Column.sessionId.name) TEXT,
            \(Column.dataJson.name) TEXT,
            \(Column.name.name) TEXT,
            \(Column.createdAt.name) INTEGER
        );
        """
    }
}
