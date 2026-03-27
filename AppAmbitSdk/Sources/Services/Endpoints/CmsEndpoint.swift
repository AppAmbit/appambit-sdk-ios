import Foundation

class CmsEndpoint: BaseEndpoint {

    init(contentType: String) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.url = "/\(contentType)"
        self.method = .get
    }

    init(contentType: String, page: Int, perPage: Int) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.url = "/\(contentType)/?per_page=\(perPage)&page=\(page)"
        self.method = .get
    }
}
