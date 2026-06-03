import Foundation
import AppAmbit

struct AuthorRelation: Decodable {
    let author: String?

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let str = try? single.decode(String.self) {
            author = str
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            author = try container.decodeIfPresent(String.self, forKey: .author)
        }
    }

    private enum CodingKeys: String, CodingKey { case author }

    var displayString: String {
        return author ?? "Unknown Author"
    }
}

struct CmsExampleModel: Decodable, Identifiable {
    let id: String?
    let title: String?
    let body: String?
    let category: [String]?
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
        case featuredImage = "featured_image_url"
        
        case viewsCount = "views_count"
        case isPublished = "is_published"
        case eventDate = "event_date"
        case scheduledPublishAt = "scheduled_publish_at"
        case authorEmail = "author_email"
        case metaData = "meta_data"
    }

    var uid: String { id ?? UUID().uuidString }
}
