class EventEndpoint: BaseEndpoint {
    
    init(event: Event) {
        super.init()
        url = "/events"
        method = .post
        payload = event
    }
}
