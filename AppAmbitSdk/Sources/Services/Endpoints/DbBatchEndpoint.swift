import Foundation

class DbBatchEndpoint: BaseEndpoint {

    init(statements: [DbStatement], transaction: Bool) {
        super.init()
        url     = "/db/batch"
        method  = .post
        payload = DbBatchRequest(statements: statements, transaction: transaction)
    }
}
