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
    @discardableResult func orWhere(_ column: String, value: Any?) -> Builder
    @discardableResult func orWhere(_ column: String, op: String, value: Any?) -> Builder
    @discardableResult func whereIn(_ column: String, values: [Any]) -> Builder
    @discardableResult func orderBy(_ column: String) -> Builder
    @discardableResult func orderByDesc(_ column: String) -> Builder
    @discardableResult func limit(_ n: Int) -> Builder
    @discardableResult func offset(_ n: Int) -> Builder
}

/// Terminal operations shared by both builders. Adding a terminal op to
/// `DbQueryBuilder` and forgetting it on `TypedDbQueryBuilder` (or vice versa)
/// now fails to compile. `get`/`first` are excluded because their return
/// types differ between the two builders.
public protocol DbWriteOperations {
    @discardableResult func insert(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken
    @discardableResult func update(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken
    @discardableResult func delete(completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken
    @discardableResult func count(completion: @escaping @Sendable (Int, Error?) -> Void) -> DbCancellationToken
}

/// How a `DbCondition` joins to the condition before it.
private enum DbConditionJoiner: String {
    case and = "AND"
    case or = "OR"
}

/// A single WHERE condition, joined to the previous one with AND/OR.
private struct DbCondition {
    let sql: String
    let params: [Any]
    let joiner: DbConditionJoiner
}

/// Mutable query configuration, held by `DbQueryBuilder` as value-type state.
private struct DbQueryState {
    var selectedColumns: [String] = []
    var conditions: [DbCondition] = []
    var orderByColumn: String?
    var orderByAscending: Bool = true
    var limitValue: Int = -1
    var offsetValue: Int = -1
    var deferredError: Error?
}

@objcMembers
public final class DbQueryBuilder: NSObject {

    private let table: String
    private let dbService: DbService?
    private var state = DbQueryState()

    init(table: String, dbService: DbService?) {
        self.table     = table
        self.dbService = dbService
    }

    // MARK: - Configuration (return self for chaining)

    @discardableResult
    public func select(_ columns: [String]) -> DbQueryBuilder {
        for col in columns where !state.selectedColumns.contains(col) {
            state.selectedColumns.append(col)
        }
        return self
    }

    @discardableResult
    public func `where`(_ column: String, value: Any?) -> DbQueryBuilder {
        addEqualityCondition(column, value: value, joiner: .and)
        return self
    }

    @discardableResult
    public func `where`(_ column: String, op: String, value: Any?) -> DbQueryBuilder {
        addOperatorCondition(column, op: op, value: value, joiner: .and)
        return self
    }

    @discardableResult
    public func orWhere(_ column: String, value: Any?) -> DbQueryBuilder {
        addEqualityCondition(column, value: value, joiner: .or)
        return self
    }

    @discardableResult
    public func orWhere(_ column: String, op: String, value: Any?) -> DbQueryBuilder {
        addOperatorCondition(column, op: op, value: value, joiner: .or)
        return self
    }

    @discardableResult
    public func whereIn(_ column: String, values: [Any]) -> DbQueryBuilder {
        guard !values.isEmpty else {
            state.deferredError = DbError.emptyInValues(column)
            return self
        }
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        addCondition(quoted(column) + " IN (\(placeholders))", params: values, joiner: .and)
        return self
    }

    @discardableResult
    public func orderBy(_ column: String) -> DbQueryBuilder {
        state.orderByColumn = column; state.orderByAscending = true; return self
    }

    @discardableResult
    public func orderByDesc(_ column: String) -> DbQueryBuilder {
        state.orderByColumn = column; state.orderByAscending = false; return self
    }

    @discardableResult
    public func limit(_ n: Int) -> DbQueryBuilder {
        state.limitValue = n; return self
    }

    @discardableResult
    public func offset(_ n: Int) -> DbQueryBuilder {
        state.offsetValue = n; return self
    }

    // MARK: - Terminal Operations

    /// Executes the query and returns all matching rows as column-keyed dictionaries.
    /// - Note: The completion closure is called on a background thread.
    ///   Dispatch to the main queue before performing any UI updates.
    /// - Returns: A token that can be used to cancel the completion callback.
    @discardableResult
    public func get(completion: @escaping @Sendable ([[String: Any]]?, Error?) -> Void) -> DbCancellationToken {
        fetchResult(overrideLimit: -1) { result, error in
            completion(result?.toMaps(), error)
        }
    }

    /// Returns the first matching row as a column-keyed dictionary.
    /// - Note: The completion closure is called on a background thread.
    ///   Dispatch to the main queue before performing any UI updates.
    /// - Returns: A token that can be used to cancel the completion callback.
    @discardableResult
    public func first(completion: @escaping @Sendable ([String: Any]?, Error?) -> Void) -> DbCancellationToken {
        fetchResult(overrideLimit: 1) { result, error in
            completion(result?.toMaps().first, error)
        }
    }

    /// Returns the count of rows matching the current WHERE conditions.
    /// - Note: The completion closure is called on a background thread.
    ///   Dispatch to the main queue before performing any UI updates.
    /// - Returns: A token that can be used to cancel the completion callback.
    @discardableResult
    public func count(completion: @escaping @Sendable (Int, Error?) -> Void) -> DbCancellationToken {
        if let err = state.deferredError { completion(0, err); return DbCancellationToken() }
        guard let svc = dbService else { completion(0, DbError.notInitialized); return DbCancellationToken() }
        var sql = "SELECT COUNT(*) FROM \(quoted(table))"
        if !state.conditions.isEmpty { sql += " WHERE \(joinedConditions())" }
        return svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams) { result, error in
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

    @discardableResult
    public func insert(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        if let err = state.deferredError { completion(nil, err); return DbCancellationToken() }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return DbCancellationToken() }
        let cols   = data.keys.sorted()
        let vals   = cols.map { data[$0]! }
        let placeholders = Array(repeating: "?", count: cols.count).joined(separator: ", ")
        let colList      = cols.map { quoted($0) }.joined(separator: ", ")
        let sql = "INSERT INTO \(quoted(table)) (\(colList)) VALUES (\(placeholders))"
        return svc.query(sql: sql, params: vals, completion: completion)
    }

    @discardableResult
    public func update(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        if let err = state.deferredError { completion(nil, err); return DbCancellationToken() }
        guard !state.conditions.isEmpty else { completion(nil, DbError.updateRequiresWhere); return DbCancellationToken() }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return DbCancellationToken() }
        let cols   = data.keys.sorted()
        let setClause = cols.map { quoted($0) + " = ?" }.joined(separator: ", ")
        let setParams = cols.map { data[$0]! }
        let sql = "UPDATE \(quoted(table)) SET \(setClause) WHERE \(joinedConditions())"
        return svc.query(sql: sql, params: setParams + whereParams, completion: completion)
    }

    @discardableResult
    public func delete(completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        if let err = state.deferredError { completion(nil, err); return DbCancellationToken() }
        guard !state.conditions.isEmpty else { completion(nil, DbError.deleteRequiresWhere); return DbCancellationToken() }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return DbCancellationToken() }
        let sql = "DELETE FROM \(quoted(table)) WHERE \(joinedConditions())"
        return svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams, completion: completion)
    }

    // MARK: - Internal

    @discardableResult
    func fetchResult(overrideLimit: Int, completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        if let err = state.deferredError { completion(nil, err); return DbCancellationToken() }
        guard let svc = dbService else { completion(nil, DbError.notInitialized); return DbCancellationToken() }
        let sql = buildSelectSQL(overrideLimit: overrideLimit)
        return svc.query(sql: sql, params: whereParams.isEmpty ? nil : whereParams) { result, error in
            if let error = error { completion(nil, error); return }
            guard let result = result else { completion(nil, DbError.noResult); return }
            if result.hasError { completion(nil, DbError.statementFailed(result.error ?? "")); return }
            completion(result, nil)
        }
    }

    func buildSelectSQL(overrideLimit: Int) -> String {
        var sql = "SELECT "
        if state.selectedColumns.isEmpty {
            sql += "*"
        } else {
            sql += state.selectedColumns.map { quoted($0) }.joined(separator: ", ")
        }
        sql += " FROM \(quoted(table))"
        if !state.conditions.isEmpty { sql += " WHERE \(joinedConditions())" }
        if let column = state.orderByColumn {
            sql += " ORDER BY \(quoted(column))" + (state.orderByAscending ? "" : " DESC")
        }
        let effective = overrideLimit > 0 ? overrideLimit : state.limitValue
        if effective > 0  { sql += " LIMIT \(effective)" }
        if state.offsetValue > 0 { sql += " OFFSET \(state.offsetValue)" }
        return sql
    }

    private var whereParams: [Any] {
        state.conditions.flatMap { $0.params }
    }

    private func addCondition(_ sql: String, params: [Any], joiner: DbConditionJoiner) {
        state.conditions.append(DbCondition(sql: sql, params: params, joiner: joiner))
    }

    private func addEqualityCondition(_ column: String, value: Any?, joiner: DbConditionJoiner) {
        addCondition(quoted(column) + " = ?", params: [value ?? NSNull()], joiner: joiner)
    }

    private func addOperatorCondition(_ column: String, op: String, value: Any?, joiner: DbConditionJoiner) {
        let upOp = op.uppercased()
        guard allowedOperators.contains(upOp) else {
            state.deferredError = DbError.invalidOperator(op)
            return
        }
        addCondition(quoted(column) + " \(upOp) ?", params: [value ?? NSNull()], joiner: joiner)
    }

    /// Joins conditions in declaration order using each condition's own joiner
    /// (e.g. `a = ? AND b = ? OR c = ?`). Standard SQL precedence applies (AND
    /// binds tighter than OR) — group with separate builders/queries if you
    /// need explicit parentheses.
    private func joinedConditions() -> String {
        state.conditions.enumerated().map { index, condition in
            index == 0 ? condition.sql : "\(condition.joiner.rawValue) \(condition.sql)"
        }.joined(separator: " ")
    }

    private func quoted(_ name: String) -> String {
        "\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

extension DbQueryBuilder: DbQueryConfiguring, DbWriteOperations {
    public typealias Builder = DbQueryBuilder
}
