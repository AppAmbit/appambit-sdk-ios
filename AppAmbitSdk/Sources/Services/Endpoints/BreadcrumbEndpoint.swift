class BreadcrumbEndpoint: BaseEndpoint {
    
    init(breadcrumbEntity: BreadcrumbEntity) {
        super.init()
        url = "/breadcrumbs"
        method = .post
        payload = breadcrumbEntity
    }
}
