class TokenEndpoint: BaseEndpoint {
    init(token: ConsumerToken) {
        super.init()
        url = "/consumer/token"
        method = .get
        payload = token
        skipAuthorization = true
    }
}
