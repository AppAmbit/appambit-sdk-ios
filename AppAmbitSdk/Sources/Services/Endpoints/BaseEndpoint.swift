class BaseEndpoint: Endpoint {
    var url: String = ""
    var baseUrl: String = AppConstants.baseUrlSdk
    var baseUrlCms: String = AppConstants.baseUrlCms
    
    var payload: Any?
    var method: HttpMethodApp = .get
    var customHeader: [String: String]?
    var skipAuthorization: Bool = false
}
