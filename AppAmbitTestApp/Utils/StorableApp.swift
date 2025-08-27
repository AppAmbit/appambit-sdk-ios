import Foundation
import SQLite3

final class StorableApp {
    static let shared: StorableApp = {
        do { return try StorableApp() }
        catch { fatalError("Failed to initialize Storable: \(error)") }
    }()

    private let queue = DispatchQueue(label: "com.appambit.sqlite", qos: .utility)
    private var db: OpaquePointer?
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let maxAttempts = 12
    private let baseDelayMs = 20
    private let maxDelayMs = 1200

    private init() throws {
        let url = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AppAmbit.sqlite")

        var tmp: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(url.path, &tmp, flags, nil)
        guard rc == SQLITE_OK, let opened = tmp else {
            throw NSError(domain: "DataStore", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }
        self.db = opened

        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")

        sqlite3_busy_timeout(db, 15000)
        
        try? exec("PRAGMA read_uncommitted=1;")
        try? exec("PRAGMA wal_autocheckpoint=1000;")
    }

    deinit {
        if let db = db { _ = sqlite3_close_v2(db) }
    }

    func close() {
        queue.sync {
            if let db = db { _ = sqlite3_close_v2(db) }
            db = nil
        }
    }

    private func sleepWithBackoff(attempt: Int) {
        let powFactor = min(attempt, 7)
        let delayMs = min(maxDelayMs, baseDelayMs * (1 << powFactor))
        let jitter = Int.random(in: 0...2500)
        usleep(useconds_t(delayMs * 1000 + jitter))
    }

    @discardableResult
    private func execRetry(_ sql: String) throws -> Void {
        var lastErr: String = "unknown"
        for attempt in 0..<maxAttempts {
            var err: UnsafeMutablePointer<Int8>?
            let rc = sqlite3_exec(db, sql, nil, nil, &err)
            if rc == SQLITE_OK { return }
            if rc == SQLITE_BUSY || rc == SQLITE_LOCKED {
                if let e = err { lastErr = String(cString: e); sqlite3_free(e) }
                sleepWithBackoff(attempt: attempt)
                continue
            }
            if let e = err { lastErr = String(cString: e); sqlite3_free(e) }
            throw NSError(domain: "SQLite3", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: lastErr])
        }
        throw NSError(domain: "SQLite3", code: Int(SQLITE_BUSY), userInfo: [NSLocalizedDescriptionKey: "execRetry exhausted attempts for: \(sql) (last: \(lastErr))"])
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown"
            if err != nil { sqlite3_free(err) }
            throw NSError(domain: "SQLite3", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private var sqliteError: NSError {
        let message = String(cString: sqlite3_errmsg(db))
        return NSError(domain: "SQLite3", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func stringFromDateIso(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.string(from: date)
    }

    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String?) {
        if let v = value {
            sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindBlob(_ stmt: OpaquePointer?, index: Int32, value: Data?) {
        if let v = value {
            _ = v.withUnsafeBytes { bytes in
                sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(v.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func inTransaction(_ body: () throws -> Void) throws {
        try execRetry("BEGIN IMMEDIATE;")
        do {
            try body()
            try execRetry("COMMIT;")
        } catch {
            _ = try? execRetry("ROLLBACK;")
            throw error
        }
    }

    func putSessionData(timestamp: Date, sessionType: String) throws {
        try queue.sync {
            try inTransaction {
                switch sessionType {
                case "start":
                    do {
                        let selectOpenSQL = """
                        SELECT id
                        FROM sessions
                        WHERE endedAt IS NULL
                        ORDER BY startedAt DESC
                        LIMIT 1;
                        """
                        var selectStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(db, selectOpenSQL, -1, &selectStmt, nil) == SQLITE_OK else { throw sqliteError }
                        defer { sqlite3_finalize(selectStmt) }

                        var openId: String?
                        if sqlite3_step(selectStmt) == SQLITE_ROW, let cstr = sqlite3_column_text(selectStmt, 0) {
                            openId = String(cString: cstr)
                        }

                        if let openId {
                            let closeSQL = """
                            UPDATE sessions
                            SET endedAt = ?
                            WHERE id = ?;
                            """
                            var closeStmt: OpaquePointer?
                            guard sqlite3_prepare_v2(db, closeSQL, -1, &closeStmt, nil) == SQLITE_OK else { throw sqliteError }
                            defer { sqlite3_finalize(closeStmt) }

                            bindText(closeStmt, index: 1, value: stringFromDateIso(timestamp))
                            bindText(closeStmt, index: 2, value: openId)

                            guard sqlite3_step(closeStmt) == SQLITE_DONE else { throw sqliteError }
                        }
                    }

                    let insertStartSQL = """
                    INSERT INTO sessions (id, sessionId, startedAt, endedAt)
                    VALUES (?, ?, ?, ?);
                    """
                    var insertStartStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, insertStartSQL, -1, &insertStartStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(insertStartStmt) }

                    bindText(insertStartStmt, index: 1, value: UUID().uuidString)
                    bindText(insertStartStmt, index: 2, value: nil)
                    bindText(insertStartStmt, index: 3, value: stringFromDateIso(timestamp))
                    bindText(insertStartStmt, index: 4, value: nil)

                    guard sqlite3_step(insertStartStmt) == SQLITE_DONE else { throw sqliteError }

                case "end":
                    let selectSQL = """
                    SELECT id FROM sessions
                    WHERE endedAt IS NULL
                    ORDER BY startedAt DESC
                    LIMIT 1;
                    """
                    var selectStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(selectStmt) }

                    var openId: String?
                    if sqlite3_step(selectStmt) == SQLITE_ROW, let idC = sqlite3_column_text(selectStmt, 0) {
                        openId = String(cString: idC)
                    }

                    if let id = openId {
                        let updateSQL = "UPDATE sessions SET endedAt = ? WHERE id = ?;"
                        var updateStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else { throw sqliteError }
                        defer { sqlite3_finalize(updateStmt) }

                        bindText(updateStmt, index: 1, value: stringFromDateIso(timestamp))
                        bindText(updateStmt, index: 2, value: id)

                        guard sqlite3_step(updateStmt) == SQLITE_DONE else { throw sqliteError }
                    } else {
                        let insertSQL = """
                        INSERT INTO sessions (id, sessionId, startedAt, endedAt)
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
    
    func updateLogsWithCurrentSessionId() throws {
        try queue.sync {
            try inTransaction {
                let selectSQL = """
                SELECT id
                FROM sessions
                WHERE endedAt IS NULL
                ORDER BY startedAt DESC
                LIMIT 1;
                """
                var selectStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(selectStmt) }

                var sessionId: String? = nil
                if sqlite3_step(selectStmt) == SQLITE_ROW, let cstr = sqlite3_column_text(selectStmt, 0) {
                    sessionId = String(cString: cstr)
                }

                guard let currentSessionId = sessionId else {
                    debugPrint("No open session found, logs not updated")
                    return
                }

                let updateByRowidSQL = """
                UPDATE logs
                SET sessionId = ?
                WHERE _rowid_ = (SELECT _rowid_ FROM logs ORDER BY _rowid_ DESC LIMIT 1);
                """
                var updateByRowidStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, updateByRowidSQL, -1, &updateByRowidStmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(updateByRowidStmt) }

                bindText(updateByRowidStmt, index: 1, value: currentSessionId)

                let stepRC1 = sqlite3_step(updateByRowidStmt)
                guard stepRC1 == SQLITE_DONE else { throw sqliteError }

                if sqlite3_changes(db) == 1 {
                    return
                }

                let updateByIdSQL = """
                UPDATE logs
                SET sessionId = ?
                WHERE id = (
                    SELECT id FROM logs
                    ORDER BY id DESC
                    LIMIT 1
                );
                """
                var updateByIdStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, updateByIdSQL, -1, &updateByIdStmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(updateByIdStmt) }

                bindText(updateByIdStmt, index: 1, value: currentSessionId)

                let stepRC2 = sqlite3_step(updateByIdStmt)
                guard stepRC2 == SQLITE_DONE else { throw sqliteError }

                if sqlite3_changes(db) == 0 {
                    debugPrint("No logs to update (table empty?)")
                }
            }
        }
    }

    public func getCurrentOpenSessionId() throws -> String? {
        try queue.sync {
            let sql = """
            SELECT id
            FROM sessions
            WHERE endedAt IS NULL
            ORDER BY startedAt DESC
            LIMIT 1;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
                return String(cString: c)
            }
            return nil
        }
    }
}
