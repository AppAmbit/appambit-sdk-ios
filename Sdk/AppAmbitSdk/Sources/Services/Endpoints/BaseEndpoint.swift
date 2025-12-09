class BaseEndpoint: Endpoint {
    var url: String = ""
    var baseUrl: String = "https://appambit.com/api"
    var payload: Any?
    var method: HttpMethodApp = .get
    var customHeader: [String: String]?
    var skipAuthorization: Bool = false
}
