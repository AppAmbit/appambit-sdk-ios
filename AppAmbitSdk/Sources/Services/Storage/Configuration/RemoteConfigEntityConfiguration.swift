struct RemoteConfigEntityConfiguration {
    private init() {}

    static let tableName = "configs"

    public enum Column: String, CaseIterable {
        case id
        case key
        case value

        public var name: String { rawValue }
    }

    static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.id.name) TEXT PRIMARY KEY,
            \(Column.key.name) TEXT,
            \(Column.value.name) TEXT
        );
        """
    }
}

