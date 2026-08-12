import Foundation

final class CloudCodeEndpoint: BaseEndpoint, @unchecked Sendable {
    init(
        function: String,
        method: CloudCodeHttpMethod,
        query: [String: String]?,
        body: [String: Any]?,
        headers: [String: String]?
    ) {
        super.init()
        self.url = Self.path(function: function, query: query)
        self.method = method.apiMethod
        self.payload = body
        self.customHeader = headers
    }

    private static func path(function: String, query: [String: String]?) -> String {
        var components = URLComponents()
        let allowedSegmentCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let encodedFunction = function.addingPercentEncoding(withAllowedCharacters: allowedSegmentCharacters) ?? function
        components.percentEncodedPath = "/fn/\(encodedFunction)"
        if let query {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.string ?? "/fn/\(function)"
    }
}
