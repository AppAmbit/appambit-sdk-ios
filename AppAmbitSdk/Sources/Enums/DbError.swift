import Foundation

public enum DbError: Error, LocalizedError {
    case notInitialized
    case noResult
    case statementFailed(String)
    case invalidOperator(String)
    case updateRequiresWhere
    case deleteRequiresWhere
    case emptyInValues(String)

    public var errorDescription: String? {
        switch self {
        case .notInitialized:           return "AppAmbitDb not initialized. Call AppAmbit.start() first."
        case .noResult:                 return "No result returned from database."
        case .statementFailed(let m):   return "Statement failed: \(m)"
        case .invalidOperator(let op):  return "Operator not allowed: \(op)"
        case .updateRequiresWhere:      return "update() without WHERE would affect all rows. Use execute() for intentional full-table updates."
        case .deleteRequiresWhere:      return "delete() without WHERE would delete all rows. Use execute() for intentional full-table deletes."
        case .emptyInValues(let col):   return "whereIn called with empty values array for column: \(col)"
        }
    }

    private var nsCode: Int {
        switch self {
        case .notInitialized:      return 1001
        case .noResult:            return 1002
        case .statementFailed:     return 1003
        case .invalidOperator:     return 1004
        case .updateRequiresWhere: return 1005
        case .deleteRequiresWhere: return 1006
        case .emptyInValues:       return 1007
        }
    }
}

extension DbError: CustomNSError {
    public static var errorDomain: String { "com.appambit.db" }
    public var errorCode: Int { nsCode }
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: errorDescription ?? ""]
    }
}
