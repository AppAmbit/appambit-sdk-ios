import Foundation

class StartSessionEndpoint : BaseEndpoint {
    init(utcNow: Date) {

        super.init()
        url = "/session/start"
        method = .post
        payload = SessionData(
            timestamp: utcNow
        )
    }
}
