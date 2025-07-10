struct SessionsConfiguration {
    private init() {}

    static let tableName = "sessions"

    public enum Column: String {
        case id
        case sessionId
        case startSessionDate
        case endSessionDate

        var name: String { rawValue }
    }

    public static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.id.name) TEXT PRIMARY KEY,
            \(Column.sessionId.name) TEXT,
            \(Column.startSessionDate.name) TEXT,
            \(Column.endSessionDate.name) TEXT
        );
        """
    }
}
