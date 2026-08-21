import Foundation

struct HTTPTransportResponse: @unchecked Sendable {
    let statusCode: Int?
    let data: Data?
    let headers: [String: String]
    let error: Error?
}

typealias CloudCodeTransportResponse = HTTPTransportResponse

protocol HTTPTransport: AnyObject {
    func executeRawRequest(
        _ endpoint: Endpoint,
        timeout: TimeInterval,
        completion: @escaping @Sendable (HTTPTransportResponse) -> Void
    )
}
