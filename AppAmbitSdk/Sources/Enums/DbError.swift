import Foundation

enum DbError: Error, LocalizedError {
    case notInitialized
    case noResult
    case statementFailed(String)
    case invalidOperator(String)
    case updateRequiresWhere
    case deleteRequiresWhere

    var errorDescription: String? {
        switch self {
        case .notInitialized:          return "AppAmbitDb not initialized. Call AppAmbit.start() first."
        case .noResult:                return "No result returned from database."
        case .statementFailed(let m):  return "Statement failed: \(m)"
        case .invalidOperator(let op): return "Operator not allowed: \(op)"
        case .updateRequiresWhere:     return "update() without WHERE would affect all rows. Use execute() for intentional full-table updates."
        case .deleteRequiresWhere:     return "delete() without WHERE would delete all rows. Use execute() for intentional full-table deletes."
        }
    }
}
