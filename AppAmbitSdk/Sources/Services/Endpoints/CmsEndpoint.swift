import Foundation

class CmsEndpoint: BaseEndpoint {

    init(contentType: String) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.url = "/\(contentType)"
        self.method = .get
    }

    init(contentType: String, page: Int) {
        super.init()
        self.baseUrl = self.baseUrlCms
        self.url = "/\(contentType)/?page=\(page)"
        self.method = .get
    }
}
