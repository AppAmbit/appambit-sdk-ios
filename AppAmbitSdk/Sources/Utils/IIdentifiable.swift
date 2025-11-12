import Foundation

public protocol IIdentifiable {
    var id: String? { get }
    var timestamp: Date { get }
}
