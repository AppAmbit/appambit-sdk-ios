import Foundation

struct DbBatchRequest: DictionaryConvertible {
    let statements: [DbStatement]
    let transaction: Bool

    func toDictionary() -> [String: Any] {
        [
            "statements": statements.map { $0.toDictionary() },
            "transaction": transaction
        ]
    }
}
