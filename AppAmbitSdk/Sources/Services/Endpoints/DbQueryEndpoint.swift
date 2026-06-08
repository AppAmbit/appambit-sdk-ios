import Foundation

class DbQueryEndpoint: BaseEndpoint {

    init(sql: String, params: [Any]?) {
        super.init()
        url     = "/db/query"
        method  = .post
        payload = DbQueryRequest(sql: sql, params: params)
    }
}
