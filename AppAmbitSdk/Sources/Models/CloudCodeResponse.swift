import Foundation

public struct CloudCodeResult<T: Decodable>: @unchecked Sendable {
    public let data: T
    public let statusCode: Int
    public let requestId: String?

    public init(data: T, statusCode: Int, requestId: String?) {
        self.data = data
        self.statusCode = statusCode
        self.requestId = requestId
    }
}

@objcMembers
public final class CloudCodeResponse: NSObject, @unchecked Sendable {
    public let data: Any
    public let statusCode: Int
    public let requestId: String?

    public init(data: Any, statusCode: Int, requestId: String?) {
        self.data = data
        self.statusCode = statusCode
        self.requestId = requestId
    }
}
