import Foundation

enum URLQueryBuilder {
    static func append(query: [String: String]?, toPath path: String) -> String {
        guard let query, !query.isEmpty else { return path }

        var components = URLComponents()
        components.percentEncodedPath = path
        components.queryItems = queryItems(from: query)
        return components.string ?? path
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
}
