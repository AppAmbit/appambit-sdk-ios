import Foundation

@objcMembers
public final class AppAmbitDb: NSObject, @unchecked Sendable {

    private nonisolated(unsafe) static var _service: DbService?
    private static let lock = NSLock()

    private static var service: DbService? {
        lock.lock(); defer { lock.unlock() }
        return _service
    }

    static func initialize(dbService: DbService) {
        lock.lock(); defer { lock.unlock() }
        _service = dbService
    }

    private static func ensureService() -> DbService? {
        guard let svc = service else {
            #if DEBUG
            debugPrint("AppAmbitDb: SDK not initialized. Call AppAmbit.start() first.")
            #endif
            return nil
        }
        return svc
    }

    // MARK: - Raw SQL

    /// Execute a single SQL statement with no parameters.
    /// - Note: The completion closure is called on a background thread. Dispatch to the main queue before any UI updates.
    public static func execute(
        _ sql: String,
        completion: @escaping @Sendable (DbResult?, Error?) -> Void
    ) {
        guard let svc = ensureService() else { completion(nil, DbError.notInitialized); return }
        svc.query(sql: sql, params: nil, completion: completion)
    }

    /// Execute a single SQL statement with positional parameters. Use ? placeholders.
    /// - Note: The completion closure is called on a background thread. Dispatch to the main queue before any UI updates.
    public static func execute(
        _ sql: String,
        params: [Any],
        completion: @escaping @Sendable (DbResult?, Error?) -> Void
    ) {
        guard let svc = ensureService() else { completion(nil, DbError.notInitialized); return }
        svc.query(sql: sql, params: params, completion: completion)
    }

    // MARK: - Batch

    /// Execute multiple statements in one API request.
    /// - Note: The completion closure is called on a background thread. Dispatch to the main queue before any UI updates.
    public static func batch(
        _ statements: [DbStatement],
        completion: @escaping @Sendable ([DbResult]?, Error?) -> Void
    ) {
        guard let svc = ensureService() else { completion(nil, DbError.notInitialized); return }
        svc.batch(statements: statements, transaction: false, completion: completion)
    }

    /// Execute multiple statements in one API request wrapped in a transaction.
    /// If any statement returns an error the entire batch is aborted.
    /// - Note: The completion closure is called on a background thread. Dispatch to the main queue before any UI updates.
    public static func batchInTransaction(
        _ statements: [DbStatement],
        completion: @escaping @Sendable ([DbResult]?, Error?) -> Void
    ) {
        guard let svc = ensureService() else { completion(nil, DbError.notInitialized); return }
        svc.batch(statements: statements, transaction: true) { results, error in
            if let error = error {
                completion(nil, error)
                return
            }
            if let results = results, let failing = results.first(where: { $0.hasError }) {
                completion(nil, DbError.statementFailed(failing.error ?? "unknown error"))
                return
            }
            completion(results, nil)
        }
    }

    // MARK: - Fluent Builder (ObjC accessible, map-based)

    /// Start a fluent query builder for the given table. Results are returned as [[String: Any]].
    public static func from(_ table: String) -> DbQueryBuilder {
        guard let svc = ensureService() else {
            return DbQueryBuilder(table: table, dbService: nil)
        }
        return DbQueryBuilder(table: table, dbService: svc)
    }
}

// MARK: - Swift-only typed builder
extension AppAmbitDb {
    /// Start a typed fluent query builder. T must be Decodable.
    /// Use CodingKeys on T to map column names to property names.
    public static func from<T: Decodable>(_ table: String, as modelType: T.Type) -> TypedDbQueryBuilder<T> {
        TypedDbQueryBuilder(inner: from(table))
    }
}
