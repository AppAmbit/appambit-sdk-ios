protocol Endpoint {
    var url: String { get set }
    var baseUrl: String { get set }
    var payload: Any? { get }
    var method: HttpMethodApp { get }
    var customHeader: [String: String]? { get set }
    var skipAuthorization: Bool { get set }    
}
