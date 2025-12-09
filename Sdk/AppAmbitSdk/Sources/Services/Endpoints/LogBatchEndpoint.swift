class LogBatchEndpoint: BaseEndpoint {
    
    init(logBatch: LogBatch) {
        super.init()
        url = "/log/batch"
        method = .post
        payload = logBatch
    }
}
