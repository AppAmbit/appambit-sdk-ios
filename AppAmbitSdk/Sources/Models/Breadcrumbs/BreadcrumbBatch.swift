import Foundation

class BreadcrumbBatch: Codable, DictionaryConvertible {
    var breadcrumbs: [BreadcrumbEntity]

    enum CodingKeys: String, CodingKey {
        case breadcrumbs = "breadcrumbs"
    }

    init(breadcrumbs: [BreadcrumbEntity]) {
        self.breadcrumbs = breadcrumbs
    }

    func toDictionary() -> [String: Any] {
        let breadcrumbsArray = breadcrumbs.map { $0.toDictionary() }
        return ["breadcrumbs": breadcrumbsArray]
    }
}
