import Foundation

struct EventResponse: Decodable {
    let id: Int?
    let name: String?
    let count: Int?
    let consumerId: Int?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case count
        case consumerId = "consumer_id"
    }
}
