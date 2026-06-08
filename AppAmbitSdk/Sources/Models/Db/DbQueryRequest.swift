import Foundation

struct DbQueryRequest: DictionaryConvertible {
    let sql: String
    let params: [Any]?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["sql": sql]
        if let params = params, !params.isEmpty { dict["params"] = params }
        return dict
    }
}
