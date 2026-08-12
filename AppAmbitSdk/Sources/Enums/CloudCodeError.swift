import Foundation

public enum CloudCodeError: Error, LocalizedError, Equatable, @unchecked Sendable {
    case notInitialized
    case invalidFunction(String)
    case invalidBody
    case invalidHeader(String)
    case networkUnavailable
    case timedOut
    case invalidURL
    case transport(String)
    case decoding(String)
    case http(statusCode: Int, body: JSONValue?, rawBody: String?, requestId: String?)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Cloud Code is not initialized. Call AppAmbit.start() first."
        case .invalidFunction(let function):
            return "Invalid Cloud Code function slug: \(function)"
        case .invalidBody:
            return "The Cloud Code body is not valid JSON."
        case .invalidHeader(let header):
            return "The Cloud Code header is reserved and cannot be overridden: \(header)"
        case .networkUnavailable:
            return "Cloud Code is unavailable because the network is offline."
        case .timedOut:
            return "Cloud Code request timed out."
        case .invalidURL:
            return "Cloud Code URL is invalid."
        case .transport(let message):
            return "Cloud Code network request failed: \(message)"
        case .decoding(let message):
            return "Cloud Code response could not be decoded: \(message)"
        case .http(let statusCode, _, let rawBody, let requestId):
            var message = "Cloud Code returned HTTP \(statusCode)."
            if let rawBody, !rawBody.isEmpty {
                message += " Body: \(rawBody)"
            }
            if let requestId {
                message += " Request ID: \(requestId)"
            }
            return message
        }
    }
}
