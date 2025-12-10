import Foundation

class EndSessionEndpoint : BaseEndpoint {
    init(endSession: SessionData) {

        super.init()
        url = "/session/end"
        method = .post
        payload = endSession
    }
}
