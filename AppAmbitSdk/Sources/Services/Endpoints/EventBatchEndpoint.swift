import Foundation

class EventBatchEndpoint: BaseEndpoint {
    
    init(eventBatch: [EventEntity]) {
        super.init()
        url = "/events/batch"
        method = .post
        payload = EventBatchPayload(events: eventBatch)
    }
        
}
