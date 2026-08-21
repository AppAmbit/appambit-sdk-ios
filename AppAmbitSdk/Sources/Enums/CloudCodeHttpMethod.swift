import Foundation

@objc public enum CloudCodeHttpMethod: Int {
    case get
    case post
    case put
    case patch
    case delete

    var apiMethod: HttpMethodApp {
        switch self {
        case .get: return .get
        case .post: return .post
        case .put: return .put
        case .patch: return .patch
        case .delete: return .delete
        }
    }
}
