import Foundation

/// Swift-only typed query builder. T must be Decodable.
/// Use CodingKeys on T to map column names to Swift property names.
public final class TypedDbQueryBuilder<T: Decodable>: DbQueryConfiguring {
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

    public func get(completion: @escaping @Sendable ([T]?, Error?) -> Void) {
        inner.fetchResult(overrideLimit: -1) { result, error in
            if let error = error { completion(nil, error); return }
            guard let result = result else { completion([], nil); return }
            completion(result.mapTo(T.self), nil)
        }
    }

    public func first(completion: @escaping @Sendable (T?, Error?) -> Void) {
        inner.fetchResult(overrideLimit: 1) { result, error in
            if let error = error { completion(nil, error); return }
            guard let result = result else { completion(nil, nil); return }
            completion(result.mapTo(T.self).first, nil)
        }
    }

    public func count(completion: @escaping @Sendable (Int, Error?) -> Void) {
        inner.count(completion: completion)
    }

    public func insert(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        inner.insert(data, completion: completion)
    }

    public func update(_ data: [String: Any], completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        inner.update(data, completion: completion)
    }

    public func delete(completion: @escaping @Sendable (DbResult?, Error?) -> Void) {
        inner.delete(completion: completion)
    }
}
