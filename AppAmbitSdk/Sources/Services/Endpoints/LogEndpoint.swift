class LogEndpoint: BaseEndpoint {
    
    init(log: Log) {
        super.init()
        url = "/log"
        method = .post
        payload = log
    }
}
