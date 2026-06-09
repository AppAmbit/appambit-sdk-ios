import Foundation

@objcMembers
public final class DbResult: NSObject, @unchecked Sendable {

    public let columns: [String]
    /// Each row is an array of column values. NSNull represents a SQL NULL.
    public let rows: [[Any]]
    public let rowsRead: Int
    public let rowsWritten: Int
    public let error: String?

    public var hasError: Bool  { error != nil }
    public var succeeded: Bool { error == nil }

    init(columns: [String], rows: [[Any]], rowsRead: Int, rowsWritten: Int, error: String?) {
        self.columns    = columns
        self.rows       = rows
        self.rowsRead   = rowsRead
        self.rowsWritten = rowsWritten
        self.error      = error
    }

    /// Returns rows as column-keyed dictionaries. NSNull values are omitted.
    public func toMaps() -> [[String: Any]] {
        rows.map { row in
            var dict = [String: Any]()
            for (i, col) in columns.enumerated() where i < row.count {
                let val = row[i]
                if !(val is NSNull) { dict[col] = val }
            }
            return dict
        }
    }
}

// MARK: - Swift-only typed mapping
extension DbResult {
    /// Decodes rows into T using JSONDecoder. T must be Decodable.
    /// Use CodingKeys on T to map column names to property names.
    public func mapTo<T: Decodable>(_ type: T.Type) -> [T] {
        let decoder = JSONDecoder()
        return toMaps().compactMap { dict in
            guard JSONSerialization.isValidJSONObject(dict),
                  let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }
    }
}
