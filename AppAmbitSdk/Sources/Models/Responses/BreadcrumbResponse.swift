import Foundation

struct BreadcrumbResponse: Decodable {
    let id: Int?
    let name: String?
    let app_id: Int?
    let occurrences_count: Int?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case app_id
        case occurrences_count = "occurrences_count"
    }
}
