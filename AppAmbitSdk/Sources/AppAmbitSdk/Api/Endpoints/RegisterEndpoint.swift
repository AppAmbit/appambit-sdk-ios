class RegisterEndpoint: BaseEndpoint {    
    init(consumer: Consumer) {
        super.init()
        url = "/consumer"
        method = .post
        payload = consumer
        skipAuthorization = true
    }
}
