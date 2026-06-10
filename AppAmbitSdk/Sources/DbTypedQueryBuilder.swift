import Foundation

/// Swift-only typed query builder. T must be Decodable.
/// Use CodingKeys on T to map column names to Swift property names.
public final class TypedDbQueryBuilder<T: Decodable>: DbQueryConfiguring, DbWriteOperations {
    public typealias Builder = TypedDbQueryBuilder<T>

    private let inner: DbQueryBuilder

    init(inner: DbQueryBuilder) {
        self.inner = inner
    }

    @discardableResult
    public func select(_ columns: [String]) -> TypedDbQueryBuilder<T> {
        inner.select(columns); return self
    }

    @discardableResult
    public func `where`(_ column: String, value: Any?) -> TypedDbQueryBuilder<T> {
        inner.`where`(column, value: value); return self
    }

    @discardableResult
    public func `where`(_ column: String, op: String, value: Any?) -> TypedDbQueryBuilder<T> {
        inner.`where`(column, op: op, value: value); return self
    }

    @discardableResult
    public func orWhere(_ column: String, value: Any?) -> TypedDbQueryBuilder<T> {
        inner.orWhere(column, value: value); return self
    }

    @discardableResult
    public func orWhere(_ column: String, op: String, value: Any?) -> TypedDbQueryBuilder<T> {
        inner.orWhere(column, op: op, value: value); return self
    }

    @discardableResult
    public func whereIn(_ column: String, values: [Any]) -> TypedDbQueryBuilder<T> {
        inner.whereIn(column, values: values); return self
    }

    @discardableResult
    public func orderBy(_ column: String) -> TypedDbQueryBuilder<T> {
        inner.orderBy(column); return self
    }

    @discardableResult
    public func orderByDesc(_ column: String) -> TypedDbQueryBuilder<T> {
        inner.orderByDesc(column); return self
    }

    @discardableResult
    public func limit(_ n: Int) -> TypedDbQueryBuilder<T> {
        inner.limit(n); return self
    }

    @discardableResult
    public func offset(_ n: Int) -> TypedDbQueryBuilder<T> {
        inner.offset(n); return self
    }

    // MARK: - Terminal ops

    @discardableResult
    public func get(completion: @escaping @Sendable ([T]?, Error?) -> Void) -> DbCancellationToken {
        inner.fetchResult(overrideLimit: -1) { result, error in
            if let error = error { completion(nil, error); return }
            completion(result!.mapTo(T.self), nil)
        }
    }

    @discardableResult
    public func first(completion: @escaping @Sendable (T?, Error?) -> Void) -> DbCancellationToken {
        inner.fetchResult(overrideLimit: 1) { result, error in
            if let error = error { completion(nil, error); return }
            completion(result!.mapTo(T.self).first, nil)
        }
    }

    @discardableResult
    public func count(completion: @escaping @Sendable (Int, Error?) -> Void) -> DbCancellationToken {
        inner.count(completion: completion)
    }

    @discardableResult
    public func insert(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        inner.insert(data, completion: completion)
    }

    @discardableResult
    public func update(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        inner.update(data, completion: completion)
    }

    @discardableResult
    public func delete(completion: @escaping @Sendable (DbResult?, Error?) -> Void) -> DbCancellationToken {
        inner.delete(completion: completion)
    }
}
