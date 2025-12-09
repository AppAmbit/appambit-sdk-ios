import Foundation

class BreadcrumbBatchEndpoint: BaseEndpoint {
    
    init(breadcrumbBatch: [BreadcrumbEntity]) {
        super.init()
        url = "/breadcrumbs/batch"
        method = .post
        payload = BreadcrumbBatch(breadcrumbs: breadcrumbBatch)
    }

}
