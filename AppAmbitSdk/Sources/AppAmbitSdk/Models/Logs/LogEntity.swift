import Foundation

class LogEntity: Log {
    var id: String = UUID().uuidString
    var createdAt: String = ""

    override func toMultipartValue() -> MultipartValue {
        let superValue = super.toMultipartValue()
        
        var dict: [String: MultipartValue]
        if case .dictionary(let existingDict) = superValue {
            dict = existingDict
        } else {
            dict = [:]
        }
        
        dict["id"] = .string(id)
        dict["created_at"] = .string(createdAt)
        
        return .dictionary(dict)
    }
}
