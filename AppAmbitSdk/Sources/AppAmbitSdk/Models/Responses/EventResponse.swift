import Foundation

struct EventResponse: Decodable {
    let id: Int
    let name: String
    let count: Int
    let consumerId: Int
    let createdAt: Date
    let updatedAt: Date
    let eventData: [EventResponseData]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case count
        case consumerId = "consumer_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case eventData = "event_data"
    }
}
