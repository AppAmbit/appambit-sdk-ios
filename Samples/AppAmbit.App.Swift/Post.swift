import Foundation
import AppAmbit

struct AuthorRelation: Decodable {
    let id: String?
    let name: String?
    let title: String?
    let email: String?
    
    var displayString: String {
        return name ?? title ?? email ?? "Unknown Author"
    }
}

struct Post: Decodable, Identifiable {
    let id: String?
    let title: String?
    let body: String?
    let category: String?
    let author: AuthorRelation?
    let featuredImage: String?
    
    let viewsCount: Double?
    let isPublished: Bool?
    let eventDate: String?
    let scheduledPublishAt: String?
    let authorEmail: String?
    let metaData: AnyDecodable?

    enum CodingKeys: String, CodingKey {
        case id, title, body, category, author
        case featuredImage = "featured_image"
        
        case viewsCount = "views_count"
        case isPublished = "is_published"
        case eventDate = "event_date"
        case scheduledPublishAt = "scheduled_publish_at"
        case authorEmail = "author_email"
        case metaData = "meta_data"
    }

    var uid: String { id ?? UUID().uuidString }
}
