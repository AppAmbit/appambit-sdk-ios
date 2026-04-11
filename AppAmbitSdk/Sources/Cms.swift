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
    
    static func decodeCmsItem<T: Decodable>(_ jsonString: String) -> T? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObj = try? JSONSerialization.jsonObject(with: data) else { return nil }
        do {
            return try T(from: FlexibleDecoder(value: jsonObj, codingPath: []))
        } catch {
            debugPrint("Cms [decode error] \(T.self): \(error)")
            return nil
        }
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
