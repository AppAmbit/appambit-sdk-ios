import Foundation

private let allowedOperators: Set<String> = [
    "=", "!=", "<>", ">", ">=", "<", "<=", "LIKE", "NOT LIKE", "IS", "IS NOT"
]

/// Compile-time contract shared by `DbQueryBuilder` and `TypedDbQueryBuilder`.
/// Adding a method here forces both builders to implement it, preventing silent divergence.
public protocol DbQueryConfiguring {
    associatedtype Builder
    @discardableResult func select(_ columns: [String]) -> Builder
    @discardableResult func `where`(_ column: String, value: Any?) -> Builder
    @discardableResult func `where`(_ column: String, op: String, value: Any?) -> Builder
    @discardableResult func whereIn(_ column: String, values: [Any]) -> Builder
    @discardableResult func orderBy(_ column: String) -> Builder
    @discardableResult func orderByDesc(_ column: String) -> Builder
    @discardableResult func limit(_ n: Int) -> Builder
    @discardableResult func offset(_ n: Int) -> Builder
}

@objcMembers
public final class DbQueryBuilder: NSObject {

    private let table: String
    private let dbService: DbService?

    private var selectedColumns: [String]  = []
    private var whereConditions: [String]  = []
    private var whereParams: [Any]         = []
    private var orderByColumn: String?     = nil
    private var ascending: Bool            = true
    private var limitValue: Int            = -1
    private var offsetValue: Int           = -1
    private var deferredError: Error?

    init(table: String, dbService: DbService?) {
        self.table     = table
        self.dbService = dbService
    }

    // MARK: - Configuration (return self for chaining)

    @discardableResult
    public func select(_ columns: [String]) -> DbQueryBuilder {
        for col in columns where !selectedColumns.contains(col) {
            selectedColumns.append(col)
        }
        return self
    }

    @discardableResult
    public func `where`(_ column: String, value: Any?) -> DbQueryBuilder {
        whereConditions.append(quoted(column) + " = ?")
        whereParams.append(value ?? NSNull())
        return self
    }

    @discardableResult
    public func `where`(_ column: String, op: String, value: Any?) -> DbQueryBuilder {
        let upOp = op.uppercased()
        guard allowedOperators.contains(upOp) else {
            deferredError = DbError.invalidOperator(op)
            return self
        }
        whereConditions.append(quoted(column) + " \(upOp) ?")
        whereParams.append(value ?? NSNull())
        return self
    }

    @discardableResult
    public func whereIn(_ column: String, values: [Any]) -> DbQueryBuilder {
        guard !values.isEmpty else {
            deferredError = DbError.emptyInValues(column)
            return self
        }
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        whereConditions.append(quoted(column) + " IN (\(placeholders))")
        whereParams.append(contentsOf: values)
        return self
    }

    @discardableResult
    public func orderBy(_ column: String) -> DbQueryBuilder {
        orderByColumn = column; ascending = true; return self
    }

    @discardableResult
    public func orderByDesc(_ column: String) -> DbQueryBuilder {
        orderByColumn = column; ascending = false; return self
    }

    @discardableResult
    public func limit(_ n: Int) -> DbQueryBuilder {
        limitValue = n; return self
    }

    @discardableResult
    public func offset(_ n: Int) -> DbQueryBuilder {
        offsetValue = n; return self
    }

    // MARK: - Terminal Operations

    public func get(completion: @escaping @Sendable ([[String: Any]]?, Error?) -> Void) {
        fetchResult(overrideLimit: -1) { result, error in
            completion(result?.toMaps(), error)
        }
    }

    public func first(completion: @escaping @Sendable ([String: Any]?, Error?) -> Void) {
        fetchResult(overrideLimit: 1) { result, error in
            completion(result?.toMaps().first, error)
        }
    }

    public func count(completion: @escaping @Sendable (Int, Error?) -> Void) {
        if let err = deferredError { completion(0, err); return }
        guard let svc = dbService else { completion(0, DbError.notInitialized); return }
        var sql = "SELECT COUNT(*) FROM \(quoted(table))"
        if !whereConditions.isEmpty { sql += " WHERE \(joinedConditions())" }
        svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams) { result, error in
            if let error = error { completion(0, error); return }
            guard let result = result else { completion(0, nil); return }
            if result.hasError { completion(0, DbError.statementFailed(result.error ?? "")); return }
            let val = result.rows.first?.first
            let n: Int
            if let num = val as? Int         { n = num }
            else if let num = val as? Double { n = Int(num) }
            else if let str = val as? String { n = Int(str) ?? 0 }
            else                             { n = 0 }
            completion(n, nil)
        }
    }

    public func insert(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        if let err = deferredError { completion(nil, err); return }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return }
        let cols   = data.keys.sorted()
        let vals   = cols.map { data[$0]! }
        let placeholders = Array(repeating: "?", count: cols.count).joined(separator: ", ")
        let colList      = cols.map { quoted($0) }.joined(separator: ", ")
        let sql = "INSERT INTO \(quoted(table)) (\(colList)) VALUES (\(placeholders))"
        svc.query(sql: sql, params: vals, completion: completion)
    }

    public func update(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        if let err = deferredError { completion(nil, err); return }
        guard !whereConditions.isEmpty else { completion(nil, DbError.updateRequiresWhere); return }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return }
        let cols   = data.keys.sorted()
        let setClause = cols.map { quoted($0) + " = ?" }.joined(separator: ", ")
        let setParams = cols.map { data[$0]! }
        let sql = "UPDATE \(quoted(table)) SET \(setClause) WHERE \(joinedConditions())"
        svc.query(sql: sql, params: setParams + whereParams, completion: completion)
    }

    public func delete(completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        if let err = deferredError { completion(nil, err); return }
        guard !whereConditions.isEmpty else { completion(nil, DbError.deleteRequiresWhere); return }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return }
        let sql = "DELETE FROM \(quoted(table)) WHERE \(joinedConditions())"
        svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams, completion: completion)
    }

    // MARK: - Internal

    func fetchResult(overrideLimit: Int, completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        if let err = deferredError { completion(nil, err); return }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return }
        let sql = buildSelectSQL(overrideLimit: overrideLimit)
        svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams) { result, error in
            if let error = error { completion(nil, error); return }
            guard let result = result else { completion(nil, DbError.noResult); return }
            if result.hasError { completion(nil, DbError.statementFailed(result.error ?? "")); return }
            completion(result, nil)
        }
    }

    func buildSelectSQL(overrideLimit: Int) -> String {
        var sql = "SELECT "
        if selectedColumns.isEmpty {
            sql += "*"
        } else {
            sql += selectedColumns.map { quoted($0) }.joined(separator: ", ")
        }
        sql += " FROM \(quoted(table))"
        if !whereConditions.isEmpty { sql += " WHERE \(joinedConditions())" }
        if let col = orderByColumn {
            sql += " ORDER BY \(quoted(col))" + (ascending ? "" : " DESC")
        }
        let effective = overrideLimit > 0 ? overrideLimit : limitValue
        if effective > 0  { sql += " LIMIT \(effective)" }
        if offsetValue > 0 { sql += " OFFSET \(offsetValue)" }
        return sql
    }

    private func joinedConditions() -> String {
        whereConditions.joined(separator: " AND ")
    }

    private func quoted(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

extension DbQueryBuilder: DbQueryConfiguring {
    public typealias Builder = DbQueryBuilder
}
