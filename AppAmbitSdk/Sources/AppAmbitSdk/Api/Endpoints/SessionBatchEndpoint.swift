class SessionBatchEndpoint: BaseEndpoint {
    init(batchSession: SessionsPayload) {
        super.init()
        url = "/session/batch"
        method = .post
        payload = batchSession
    }
}
