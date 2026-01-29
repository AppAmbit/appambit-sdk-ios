class UpdateConsumerEndpoint: BaseEndpoint {
    init(consumerId: String, request: UpdateConsumer) {
        super.init()
        url = "/consumer/\(consumerId)"
        method = .put
        payload = request
    }
}
