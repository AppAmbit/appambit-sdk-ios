import Foundation

struct CloudCodeTransportResponse: @unchecked Sendable {
    let statusCode: Int?
    let data: Data?
    let headers: [String: String]
    let error: Error?
}

protocol CloudCodeTransport: AnyObject {
    func executeCloudCodeRequest(
        _ endpoint: CloudCodeEndpoint,
        timeout: TimeInterval,
        completion: @escaping @Sendable (CloudCodeTransportResponse) -> Void
    )
}
