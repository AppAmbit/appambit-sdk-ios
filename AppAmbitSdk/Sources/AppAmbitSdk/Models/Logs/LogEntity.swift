import Foundation

class LogEntity: Log {
    var id: String?
    var createdAt: Date?

    override func toMultipartValue() -> MultipartValue {
        let superValue = super.toMultipartValue()
        
        var dict: [String: MultipartValue]
        if case .dictionary(let existingDict) = superValue {
            dict = existingDict
        } else {
            dict = [:]
        }
        
        dict["id"] = .string(id ?? "")
        
        if createdAt != nil {
            let createdAtString = DateUtils.utcCustomFormatString(from: createdAt!)
        
            dict["created_at"] = .string(createdAtString)
                        
        } else {
            dict["created_at"] = .string("")
        }
        
        return .dictionary(dict)
    }
}

