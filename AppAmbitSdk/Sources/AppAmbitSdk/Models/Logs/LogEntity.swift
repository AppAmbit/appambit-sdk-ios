import Foundation

class LogEntity: Log {
    var id: String = UUID().uuidString
    var createdAt: Date = DateUtils.utcNow

    override func toMultipartValue() -> MultipartValue {
        let superValue = super.toMultipartValue()
        
        var dict: [String: MultipartValue]
        if case .dictionary(let existingDict) = superValue {
            dict = existingDict
        } else {
            dict = [:]
        }
        
        dict["id"] = .string(id)
        
        let createdAtString = DateUtils.utcCustomFormatString(from: createdAt)
    
        dict["created_at"] = .string(createdAtString)
        
        return .dictionary(dict)
    }
}

