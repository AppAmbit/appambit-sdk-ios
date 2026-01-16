struct AppSecretsConfiguration {
    private init() {}

    public static let tableName = "secrets"

    public enum Column: String {
        case id
        case consumerId
        case appId
        case deviceId
        case token
        case sessionId
        case userId
        case userEmail
        case deviceToken
        case pushEnabled
        
        var name: String { rawValue }
    }

    public static var createTable: String {
        """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            \(Column.id.name) TEXT PRIMARY KEY,
            \(Column.consumerId.name) TEXT,        
            \(Column.appId.name) TEXT,
            \(Column.deviceId.name) TEXT,
            \(Column.token.name) TEXT,
            \(Column.sessionId.name) TEXT,
            \(Column.userId.name) TEXT,
            \(Column.userEmail.name) TEXT,
            \(Column.deviceToken.name) TEXT,
            \(Column.pushEnabled.name) INTEGER DEFAULT 1
        );
        """
    }
}
