import Foundation

struct EventResponseData: Codable {
    let id: String
    let key: String
    let value: String
    let count: Int
    let eventId: Int
    
    private enum CodingKeys: String, CodingKey {
        case id
        case key
        case value
        case count
        case eventId = "event_id"
    }
}
