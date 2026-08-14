import Foundation

final class CloudCodeEndpoint: BaseEndpoint, @unchecked Sendable {
    let bodyData: Data?

    init(
        function: String,
        method: CloudCodeHttpMethod,
        query: [String: String]?,
        body: [String: Any]?,
        headers: [String: String]?
    ) {
        bodyData = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        super.init()
        self.url = Self.path(function: function, query: query)
        self.method = method.apiMethod
        self.payload = body
        self.customHeader = headers
    }

    private static func path(function: String, query: [String: String]?) -> String {
        let allowedSegmentCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let encodedFunction = function.addingPercentEncoding(withAllowedCharacters: allowedSegmentCharacters) ?? function
        return URLQueryBuilder.append(
            query: query,
            toPath: "/fn/\(encodedFunction)"
        )
    }
}
