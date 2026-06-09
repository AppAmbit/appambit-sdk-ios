import Foundation

@objcMembers
public final class DbStatement: NSObject, @unchecked Sendable {

    public let sql: String
    public let params: [Any]?

    /// Create a statement, optionally with positional parameters. Use ? placeholders in the SQL.
    public init(sql: String, params: [Any]? = nil) {
        self.sql    = sql
        self.params = (params?.isEmpty ?? true) ? nil : params
    }

    /// Create a statement with no parameters.
    public static func of(_ sql: String) -> DbStatement {
        DbStatement(sql: sql, params: nil)
    }

    /// Create a statement with positional parameters. Use ? placeholders in the SQL.
    public static func of(_ sql: String, params: [Any]) -> DbStatement {
        DbStatement(sql: sql, params: params)
    }

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["sql": sql]
        if let params = params, !params.isEmpty { dict["params"] = params }
        return dict
    }
}
