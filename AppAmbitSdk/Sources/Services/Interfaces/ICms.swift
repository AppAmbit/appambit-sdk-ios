import Foundation

public protocol ICms {
    static func content<T: Decodable>(_ contentType: String, modelType: T.Type) -> CmsQuery<T>
    static func content(_ contentType: String) -> CmsQuery<JSONValue>
    static func contentObjC(_ contentType: String) -> CmsQueryObjC
    static func contentTypelessObjC(_ contentType: String) -> CmsQueryObjC
    static func clearCache(_ contentType: String)
    static func clearAllCache()
}
