struct LogEntityConfiguration {
    private init() {}

    static let tableName = "logs"

    public enum Column: String {
        case id
        case appVersion
        case classFQN
        case fileName
        case lineNumber
        case message
        case stackTrace
        case contextJson
        case type
        case file
        case createdAt

        public var name: String { rawValue }
    }

    static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.id.name) TEXT PRIMARY KEY,
            \(Column.appVersion.name) TEXT,
            \(Column.classFQN.name) TEXT,
            \(Column.fileName.name) TEXT,
            \(Column.lineNumber.name) INTEGER,
            \(Column.message.name) TEXT,
            \(Column.stackTrace.name) TEXT,
            \(Column.contextJson.name) TEXT,
            \(Column.type.name) TEXT,
            \(Column.file.name) TEXT,
            \(Column.createdAt.name) INTEGER
        );
        """
    }
}
