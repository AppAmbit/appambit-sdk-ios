import Foundation

class CmsEndpoint: BaseEndpoint {

    init(contentType: String, queryItems: [(String, String)] = [], isSearch: Bool = false) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.method = .get

        let path = isSearch ? "/\(contentType)/search" : "/\(contentType)"

        if queryItems.isEmpty {
            self.url = path
        } else {
            var components = URLComponents()
            components.queryItems = queryItems.map { URLQueryItem(name: $0.0, value: $0.1) }
            let queryString = components.percentEncodedQuery ?? ""
            self.url = queryString.isEmpty ? path : "\(path)?\(queryString)"
        }
    }

    init(contentType: String) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.url = "/\(contentType)"
        self.method = .get
    }
}
