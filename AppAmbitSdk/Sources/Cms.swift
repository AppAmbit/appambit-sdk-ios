import Foundation

@objcMembers
public final class Cms: NSObject {
    fileprivate nonisolated(unsafe) static var apiService: ApiService!
    fileprivate nonisolated(unsafe) static var storageService: StorageService!
    fileprivate static let fetchedContentTypes = ThreadSafeSet<String>()

    static func initialize(apiService: ApiService, storageService: StorageService) {
        self.apiService = apiService
        self.storageService = storageService
    }

    public static func content<T: Decodable>(_ contentType: String, modelType: T.Type) -> CmsQuery<T> {
        return CmsQuery<T>(contentType: contentType)
    }

    public static func content(_ contentType: String) -> CmsQuery<JSONValue> {
        return CmsQuery<JSONValue>(contentType: contentType)
    }

    @objc(contentWithType:)
    public static func contentObjC(_ contentType: String) -> CmsQueryObjC {
        return CmsQueryObjC(contentType: contentType)
    }

    @objc(content:)
    public static func contentTypelessObjC(_ contentType: String) -> CmsQueryObjC {
        return CmsQueryObjC(contentType: contentType)
    }

    @objc(clearWithContentType:)
    public static func clear(_ contentType: String) {
        guard storageService != nil else { return }
        do {
            try storageService.deleteCmsData(contentType)
            fetchedContentTypes.remove(contentType)
        } catch {
            debugPrint("Cms [clear error]: \(error)")
        }
    }

    @objc
    public static func clearAll() {
        guard storageService != nil else { return }
        do {
            try storageService.deleteAllCmsData()
            fetchedContentTypes.removeAll()
        } catch {
            debugPrint("Cms [clearAll error]: \(error)")
        }
    }
}

// MARK: - Generic Query Builder

public final class CmsQuery<T: Decodable>: @unchecked Sendable {
    private let contentType: String
    private var whereClause: String = ""
    private var args: [String] = []
    private var orderBy: String?
    private var page: Int?
    private var perPage: Int?

    init(contentType: String) {
        self.contentType = contentType
    }

    private func addCondition(_ field: String, _ op: String, _ value: String) {
        if !whereClause.isEmpty { whereClause += " AND " }
        whereClause += "json_extract(value, '$.\(field)') \(op) ?"
        args.append(value)
    }

    private func addNumericCondition(_ field: String, _ op: String, _ value: Any) {
        if !whereClause.isEmpty { whereClause += " AND " }
        whereClause += "CAST(json_extract(value, '$.\(field)') AS REAL) \(op) ?"
        args.append("\(value)")
    }

    public func search(_ query: String) -> Self {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if !whereClause.isEmpty { whereClause += " AND " }
            whereClause += "value LIKE ?"
            args.append("%\(trimmed)%")
        }
        return self
    }

    public func equals(_ field: String, _ value: String) -> Self { addCondition(field, "=", value); return self }
    public func notEquals(_ field: String, _ value: String) -> Self { addCondition(field, "!=", value); return self }
    public func contains(_ field: String, _ value: String) -> Self { addCondition(field, "LIKE", "%\(value)%"); return self }
    public func startsWith(_ field: String, _ value: String) -> Self { addCondition(field, "LIKE", "\(value)%"); return self }
    public func greaterThan(_ field: String, _ value: Any) -> Self { addNumericCondition(field, ">", value); return self }
    public func greaterThanOrEqual(_ field: String, _ value: Any) -> Self { addNumericCondition(field, ">=", value); return self }
    public func lessThan(_ field: String, _ value: Any) -> Self { addNumericCondition(field, "<", value); return self }
    public func lessThanOrEqual(_ field: String, _ value: Any) -> Self { addNumericCondition(field, "<=", value); return self }

    public func inList(_ field: String, _ values: [String]) -> Self {
        if !whereClause.isEmpty { whereClause += " AND " }
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        whereClause += "json_extract(value, '$.\(field)') IN (\(placeholders))"
        args.append(contentsOf: values)
        return self
    }

    public func notInList(_ field: String, _ values: [String]) -> Self {
        if !whereClause.isEmpty { whereClause += " AND " }
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        whereClause += "json_extract(value, '$.\(field)') NOT IN (\(placeholders))"
        args.append(contentsOf: values)
        return self
    }

    public func orderByAscending(_ field: String) -> Self {
        self.orderBy = "json_extract(value, '$.\(field)') ASC"
        return self
    }

    public func orderByDescending(_ field: String) -> Self {
        self.orderBy = "json_extract(value, '$.\(field)') DESC"
        return self
    }

    public func setPage(_ page: Int) -> Self { self.page = page; return self }
    public func setPerPage(_ perPage: Int) -> Self { self.perPage = perPage; return self }

    public func getList(completion: @escaping @Sendable ([T]) -> Void) {
        let limit = perPage ?? -1
        let offset = perPage != nil ? ((page ?? 1) - 1) * perPage! : 0

        if Cms.fetchedContentTypes.contains(contentType) {
            let cached = queryLocalCache(orderBy: orderBy, limit: limit, offset: offset)
            completion(cached)
            return
        }

        Cms.fetchedContentTypes.insert(contentType)

        let cached = queryLocalCache(orderBy: orderBy, limit: limit, offset: offset)
        if cached.isEmpty {
            fetchAndReturn(orderBy: orderBy, limit: limit, offset: offset, completion: completion)
        } else {
            completion(cached)
            refreshCacheInBackground()
        }
    }

    private func queryLocalCache(orderBy: String?, limit: Int, offset: Int) -> [T] {
        do {
            let jsonList = try Cms.storageService.queryCmsData(
                contentType: contentType,
                whereClause: whereClause,
                args: args,
                orderBy: orderBy,
                limit: limit,
                offset: offset
            )
            let decoder = JSONDecoder()
            return jsonList.compactMap { jsonString in
                guard let data = jsonString.data(using: .utf8) else { return nil }
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    debugPrint("Cms [decode error] \(T.self): \(error)")
                    return nil
                }
            }
        } catch {
            return []
        }
    }

    private func fetchAndReturn(orderBy: String?, limit: Int, offset: Int, completion: @escaping @Sendable ([T]) -> Void) {
        fetchAllRemoteDataSync { _ in
            completion(self.queryLocalCache(orderBy: orderBy, limit: limit, offset: offset))
        }
    }

    private func refreshCacheInBackground() {
        fetchAllRemoteDataSync { _ in }
    }

    private func fetchAllRemoteDataSync(completion: @escaping @Sendable (Bool) -> Void) {
        let perPageFetch = 20
        let endpoint = CmsEndpoint(contentType: contentType, page: 1, perPage: perPageFetch)
        
        Cms.apiService.executeRequest(endpoint, responseType: [String: JSONValue].self) { result in
            guard let responseDict = result.data else {
                debugPrint("Cms [fetch error]: Unable to decode JSON or response is nil. Result error: \(String(describing: result.errorType))")
                completion(false)
                return
            }

            guard case let .array(dataArray) = responseDict["data"] else {
                self.storeRawDict(responseDict, completion: completion)
                return
            }

            var total = 0
            if case let .object(metaObj) = responseDict["meta"],
               case let .int(t) = metaObj["total"] {
                total = t
            }

            let totalPages = Int(ceil(Double(total) / Double(perPageFetch)))

            if totalPages <= 1 {
                self.storeRawDict(responseDict, completion: completion)
            } else {
                self.fetchRemainingPages(startPage: 2, totalPages: totalPages, perPage: perPageFetch) { finalExtraItems in
                    var allItems = dataArray
                    allItems.append(contentsOf: finalExtraItems)
                    var localDict = responseDict
                    localDict["data"] = .array(allItems)
                    self.storeRawDict(localDict, completion: completion)
                }
            }
        }
    }

    private func fetchRemainingPages(startPage: Int, totalPages: Int, perPage: Int, completion: @escaping @Sendable ([JSONValue]) -> Void) {
        let items = ThreadSafeArray<JSONValue>(initialItems: [])
        let group = DispatchGroup()
        
        for p in startPage...totalPages {
            group.enter()
            let endpoint = CmsEndpoint(contentType: contentType, page: p, perPage: perPage)
            Cms.apiService.executeRequest(endpoint, responseType: [String: JSONValue].self) { result in
                if let dict = result.data, case let .array(nextData) = dict["data"] {
                    items.append(contentsOf: nextData)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            completion(items.all())
        }
    }

    private func storeRawDict(_ dict: [String: JSONValue], completion: @escaping @Sendable (Bool) -> Void) {
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(dict)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                try Cms.storageService.putCmsData(contentType, jsonString)
                debugPrint("Cms [store success]: Stored data for \(contentType)")
                completion(true)
            } else {
                completion(false)
            }
        } catch {
            debugPrint("Cms [store error]: Failed to store data for \(contentType). Error: \(error)")
            completion(false)
        }
    }
}

// MARK: - ObjC Component

@objcMembers
public final class CmsQueryObjC: NSObject, @unchecked Sendable {
    private let contentType: String
    private let internalQuery: CmsQuery<JSONValue>

    init(contentType: String) {
        self.contentType = contentType
        self.internalQuery = CmsQuery<JSONValue>(contentType: contentType)
    }

    @objc(search:)
    public func search(_ query: String) -> Self { _ = internalQuery.search(query); return self }
    @objc(equals:value:)
    public func equals(_ field: String, _ value: String) -> Self { _ = internalQuery.equals(field, value); return self }
    @objc(notEquals:value:)
    public func notEquals(_ field: String, _ value: String) -> Self { _ = internalQuery.notEquals(field, value); return self }
    @objc(contains:value:)
    public func contains(_ field: String, _ value: String) -> Self { _ = internalQuery.contains(field, value); return self }
    @objc(startsWith:value:)
    public func startsWith(_ field: String, _ value: String) -> Self { _ = internalQuery.startsWith(field, value); return self }
    @objc(greaterThan:value:)
    public func greaterThan(_ field: String, _ value: Any) -> Self { _ = internalQuery.greaterThan(field, value); return self }
    @objc(greaterThanOrEqual:value:)
    public func greaterThanOrEqual(_ field: String, _ value: Any) -> Self { _ = internalQuery.greaterThanOrEqual(field, value); return self }
    @objc(lessThan:value:)
    public func lessThan(_ field: String, _ value: Any) -> Self { _ = internalQuery.lessThan(field, value); return self }
    @objc(lessThanOrEqual:value:)
    public func lessThanOrEqual(_ field: String, _ value: Any) -> Self { _ = internalQuery.lessThanOrEqual(field, value); return self }
    @objc(inList:values:)
    public func inList(_ field: String, _ values: [String]) -> Self { _ = internalQuery.inList(field, values); return self }
    @objc(notInList:values:)
    public func notInList(_ field: String, _ values: [String]) -> Self { _ = internalQuery.notInList(field, values); return self }
    @objc(orderByAscending:)
    public func orderByAscending(_ field: String) -> Self { _ = internalQuery.orderByAscending(field); return self }
    @objc(orderByDescending:)
    public func orderByDescending(_ field: String) -> Self { _ = internalQuery.orderByDescending(field); return self }
    @objc(setPage:)
    public func setPage(_ page: Int) -> Self { _ = internalQuery.setPage(page); return self }
    @objc(setPerPage:)
    public func setPerPage(_ perPage: Int) -> Self { _ = internalQuery.setPerPage(perPage); return self }

    @objc(getListWithCompletion:)
    public func getList(completion: @escaping @Sendable ([Any]) -> Void) {
        internalQuery.getList { items in
            completion(items.map { $0.toAny() })
        }
    }
}

// MARK: - JSON Handling

public enum JSONValue: Codable, @unchecked Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) { self = .int(x) }
        else if let x = try? container.decode(Double.self) { self = .double(x) }
        else if let x = try? container.decode(Bool.self) { self = .bool(x) }
        else if let x = try? container.decode(String.self) {
            let lowercased = x.lowercased()
            if let intVal = Int(x) {
                self = .int(intVal)
            } else if let doubleVal = Double(x) {
                self = .double(doubleVal)
            } else if lowercased == "true" || lowercased == "1" {
                self = .bool(true)
            } else if lowercased == "false" || lowercased == "0" {
                self = .bool(false)
            } else {
                self = .string(x)
            }
        }
        else if let x = try? container.decode([String: JSONValue].self) { self = .object(x) }
        else if let x = try? container.decode([JSONValue].self) { self = .array(x) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Wrong type for JSONValue") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .int(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .object(let x): try container.encode(x)
        case .array(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }

    public func toAny() -> Any {
        switch self {
        case .string(let x): return x
        case .int(let x): return x
        case .double(let x): return x
        case .bool(let x): return x
        case .object(let x): return x.mapValues { $0.toAny() }
        case .array(let x): return x.map { $0.toAny() }
        case .null: return NSNull()
        }
    }
}

public struct AnyDecodable: Decodable, CustomStringConvertible, @unchecked Sendable {
    public let value: Any
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let dict = try? container.decode([String: AnyDecodable].self) { value = dict }
        else if let array = try? container.decode([AnyDecodable].self) { value = array }
        else if container.decodeNil() { value = "null" }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable invalid") }
    }
    
    public var description: String {
        if let dict = value as? [String: AnyDecodable] {
            return "{" + dict.map { "\($0.key): \($0.value.description)" }.joined(separator: ", ") + "}"
        }
        if let array = value as? [AnyDecodable] {
            return "[" + array.map { $0.description }.joined(separator: ", ") + "]"
        }
        return "\(value)"
    }
}

private final class ThreadSafeSet<T: Hashable>: @unchecked Sendable {
    private var set = Set<T>()
    private let lock = NSLock()

    init() {}

    func insert(_ element: T) {
        lock.lock(); defer { lock.unlock() }
        set.insert(element)
    }

    func contains(_ element: T) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return set.contains(element)
    }

    func remove(_ element: T) {
        lock.lock(); defer { lock.unlock() }
        set.remove(element)
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        set.removeAll()
    }
}
private final class ThreadSafeArray<T>: @unchecked Sendable {
    private var array: [T]
    private let lock = NSLock()

    init(initialItems: [T]) {
        self.array = initialItems
    }

    func append(contentsOf items: [T]) {
        lock.lock(); defer { lock.unlock() }
        array.append(contentsOf: items)
    }

    func all() -> [T] {
        lock.lock(); defer { lock.unlock() }
        return array
    }
}
