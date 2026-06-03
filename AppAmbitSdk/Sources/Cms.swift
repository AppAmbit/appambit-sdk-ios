import Foundation

@objcMembers
public final class Cms: NSObject {
    private static let _lock = NSLock()
    nonisolated(unsafe) private static var _apiService: ApiService!

    internal static var apiService: ApiService! {
        get { _lock.lock(); defer { _lock.unlock() }; return _apiService }
        set { _lock.lock(); defer { _lock.unlock() }; _apiService = newValue }
    }

    static func initialize(apiService: ApiService) {
        self.apiService = apiService
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

    static func decodeCmsItem<T: Decodable>(_ jsonValue: JSONValue) -> T? {
        let anyValue = jsonValue.toAny()
        do {
            return try T(from: FlexibleDecoder(value: anyValue, codingPath: []))
        } catch {
            debugPrint("Cms [decode error] \(T.self): \(error)")
            return nil
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
