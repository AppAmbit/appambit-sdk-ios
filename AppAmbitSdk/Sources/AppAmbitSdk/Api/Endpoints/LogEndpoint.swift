class LogEndpoint: BaseEndpoint {
    
    init(log: LogEntity) {
        super.init()
        url = "/log"
        method = .post
        payload = log
    }
}
