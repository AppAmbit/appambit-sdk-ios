import Foundation

enum ApiExceptions: Error {
    case invalidURL
    case networkError(URLError)
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case unauthorized
}
