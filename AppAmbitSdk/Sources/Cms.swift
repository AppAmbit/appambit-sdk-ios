import Foundation

@objcMembers
public final class Cms: NSObject {
    private static let _lock = NSLock()
    nonisolated(unsafe) private static var _apiService: ApiService!
    nonisolated(unsafe) private static var _storageService: StorageService!

    internal static var apiService: ApiService! {
        get { _lock.lock(); defer { _lock.unlock() }; return _apiService }
        set { _lock.lock(); defer { _lock.unlock() }; _apiService = newValue }
    }

    internal static var storageService: StorageService! {
        get { _lock.lock(); defer { _lock.unlock() }; return _storageService }
        set { _lock.lock(); defer { _lock.unlock() }; _storageService = newValue }
    }
    internal static let fetchedContentTypes = ThreadSafeSet<String>()

    static func initialize(apiService: ApiService, storageService: StorageService) {
        self.apiService = apiService
        self.storageService = storageService
    }

    internal static func resetFetchState(_ contentType: String? = nil) {
        if let contentType {
            fetchedContentTypes.remove(contentType)
        } else {
            fetchedContentTypes.removeAll()
        }
    }

    public static func content<T: Decodable>(_ contentType: String, modelType: T.Type) -> any ICmsQuery<T> {
        return CmsQuery<T>(contentType: contentType)
    }

    public static func content(_ contentType: String) -> any ICmsQuery<JSONValue> {
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

    @discardableResult
    @objc
    public static func clearCache(_ contentType: String) async -> Bool {
        guard storageService != nil else { return false }
        do {
            try storageService.deleteCmsData(contentType)
            resetFetchState(contentType)
            return true
        } catch {
            debugPrint("Cms [clearCache error]: \(error)")
            return false
        }
    }

    @discardableResult
    @objc
    public static func clearAllCache() async -> Bool {
        guard storageService != nil else { return false }
        do {
            try storageService.deleteAllCmsData()
            resetFetchState()
            return true
        } catch {
            debugPrint("Cms [clearAllCache error]: \(error)")
            return false
        }
    }
    
    static func decodeCmsItem<T: Decodable>(_ jsonString: String, decoder: JSONDecoder) -> T? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            if case .typeMismatch = error,
               var dict = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] {
                var mutated = false
                for (key, val) in dict {
                    if let arr = val as? [Any] {
                        dict[key] = arr.map { "\($0)" }.joined(separator: ", ")
                        mutated = true
                    }
                }
                if mutated,
                   let patchedData = try? JSONSerialization.data(withJSONObject: dict, options: []),
                   let result = try? decoder.decode(T.self, from: patchedData) {
                    return result
                }
            }
            debugPrint("Cms [decode error] \(T.self): \(error)")
            return nil
        } catch {
            debugPrint("Cms [decode error] \(T.self): \(error)")
            return nil
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
        if let x = try? container.decode(Bool.self) { self = .bool(x) }
        else if let x = try? container.decode(Int.self) { self = .int(x) }
        else if let x = try? container.decode(Double.self) { self = .double(x) }
        else if let x = try? container.decode(String.self) {
            if let intVal = Int(x) { self = .int(intVal) }
            else if let doubleVal = Double(x) { self = .double(doubleVal) }
            else if x.lowercased() == "true" { self = .bool(true) }
            else if x.lowercased() == "false" { self = .bool(false) }
            else { self = .string(x) }
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
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let string = try? container.decode(String.self) {
            if let intVal = Int(string) { value = intVal }
            else if let doubleVal = Double(string) { value = doubleVal }
            else if string.lowercased() == "true" { value = true }
            else if string.lowercased() == "false" { value = false }
            else { value = string }
        }
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

internal final class ThreadSafeSet<T: Hashable>: @unchecked Sendable {
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
internal final class ThreadSafeArray<T>: @unchecked Sendable {
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
