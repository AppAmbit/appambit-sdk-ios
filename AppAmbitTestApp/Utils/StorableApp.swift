
import Foundation
import SQLite3

class StorableApp {
    static let shared: StorableApp = {
        do {
            return try StorableApp()
        } catch {
            fatalError("Failed to initialize Storable: \(error)")
        }
    }()
    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.appaambitestingapp.storage", qos: .utility)
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private init() throws {
        var tmpDb: OpaquePointer?
        let pathdb = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AppAmbit.sqlite")
        let result = sqlite3_open(pathdb.path, &tmpDb)
        guard result == SQLITE_OK else {
            throw NSError(domain: "DataStore", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }
        self.db = tmpDb
    }
    
    private func stringFromDateIso(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.string(from: date)
    }
    
    private var sqliteError: NSError {
        let message = String(cString: sqlite3_errmsg(db))
        return NSError(domain: "SQLite3", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    func bindText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
    
    func bindBlob(_ stmt: OpaquePointer?, index: Int32, value: Data?) {
        if let v = value {
            _ = v.withUnsafeBytes { bytes in
                sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(v.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
    
    func putSessionData(timestamp:Date, sessionType:String) throws {
        try queue.sync {
            switch sessionType {
            case "start":
                let sql = """
                INSERT INTO sessions
                (id, sessionId, startSessionDate, endSessionDate)
                VALUES (?, ?, ?, ?);
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(stmt) }
                
                bindText(stmt, index: 1, value: UUID().uuidString)
                bindText(stmt, index: 2, value: nil)
                bindText(stmt, index: 3, value: stringFromDateIso(timestamp))
                bindText(stmt, index: 4, value: nil)
                
                guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
                
            case "end":
                let selectSQL = """
                SELECT id FROM sessions
                WHERE endSessionDate IS NULL
                ORDER BY startSessionDate DESC
                LIMIT 1;
                """
                var selectStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(selectStmt) }
                
                var foundId: String? = nil
                if sqlite3_step(selectStmt) == SQLITE_ROW {
                    if let idCStr = sqlite3_column_text(selectStmt, 0) {
                        foundId = String(cString: idCStr)
                    }
                }
                
                if let openId = foundId {
                    let updateSQL = """
                    UPDATE sessions
                    SET endSessionDate = ?
                    WHERE id = ?;
                    """
                    var updateStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(updateStmt) }
                    
                    bindText(updateStmt, index: 1, value: stringFromDateIso(timestamp))
                    bindText(updateStmt, index: 2, value: openId)
                    
                    guard sqlite3_step(updateStmt) == SQLITE_DONE else { throw sqliteError }
                    
                } else {
                    let insertSQL = """
                    INSERT INTO sessions
                    (id, sessionId, startSessionDate, endSessionDate)
                    VALUES (?, ?, ?, ?);
                    """
                    var insertStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(insertStmt) }
                    
                    bindText(insertStmt, index: 1, value: UUID().uuidString)
                    bindText(insertStmt, index: 2, value: nil)
                    bindText(insertStmt, index: 3, value: nil)
                    bindText(insertStmt, index: 4, value: stringFromDateIso(timestamp))
                    
                    guard sqlite3_step(insertStmt) == SQLITE_DONE else { throw sqliteError }
                }
                
            default:
                debugPrint("The session type does not exist")
            }
        }
    }
}
