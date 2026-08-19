import Foundation

enum URLQueryBuilder {
    private static let allowedQueryCharacters = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))

    static func append(query: [String: String]?, toPath path: String) -> String {
        guard let query, !query.isEmpty else { return path }

        let queryString = percentEncodedQuery(from: query)
        guard !queryString.isEmpty else { return path }
        return path + (path.contains("?") ? "&" : "?") + queryString
    }

    static func queryItems(from query: [String: String]) -> [URLQueryItem] {
        query.keys.sorted().map { key in
            URLQueryItem(name: key, value: query[key])
        }
    }

    static func queryItems(from dictionary: [String: Any]) -> [URLQueryItem] {
        dictionary.keys.sorted().map { key in
            URLQueryItem(name: key, value: String(describing: dictionary[key]!))
        }
    }

    static func percentEncodedQuery(from query: [String: String]) -> String {
        query.keys.sorted().compactMap { key in
            guard let value = query[key] else { return nil }
            return "\(encode(key))=\(encode(value))"
        }.joined(separator: "&")
    }

    static func percentEncodedQuery(from dictionary: [String: Any]) -> String {
        dictionary.keys.sorted().map { key in
            "\(encode(key))=\(encode(String(describing: dictionary[key]!)))"
        }.joined(separator: "&")
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: allowedQueryCharacters) ?? value
    }
}
