import Foundation

public protocol ICms {
    static func content<T: Decodable>(_ contentType: String, modelType: T.Type) -> any ICmsQuery<T>
    static func content(_ contentType: String) -> any ICmsQuery<JSONValue>
    static func contentObjC(_ contentType: String) -> CmsQueryObjC
    static func contentTypelessObjC(_ contentType: String) -> CmsQueryObjC
    static func clearCache(_ contentType: String) -> Bool
    static func clearAllCache() -> Bool
}
