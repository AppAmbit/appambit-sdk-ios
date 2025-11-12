import Foundation

public struct BreadcrumbData: Codable, IIdentifiable {
    public let id: String?
    public let sessionId: String
    public let name: String
    public let timestamp: Date
}



extension BreadcrumbData {
    func toEntity() -> BreadcrumbEntity {
        BreadcrumbEntity(id: id ?? UUID().uuidString, sessionId: sessionId, name: name, createdAt: timestamp)
    }
}
