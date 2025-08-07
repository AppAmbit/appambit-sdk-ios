import Foundation
import SQLite3

class StorableService: StorageService {
    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.appambit.storage.service", qos: .utility)
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    init(ds: DataStore) throws {
        var tmpDb: OpaquePointer?
        let result = sqlite3_open(ds.dbPath, &tmpDb)
        guard result == SQLITE_OK else {
            throw NSError(domain: "DataStore", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }
        self.db = tmpDb
    }
    
    private func dateFromStringCustom(_ value: String) -> Date? {
        return DateUtils.utcCustomFormatDate(from: value)
    }
    
    private func stringFromDateCustom(_ date: Date) -> String {
        return DateUtils.utcCustomFormatString(from: date)
    }
    
    private func dateFromStringIso(_ value: String) -> Date? {
        DateUtils.utcIsoFormatDate(from: value)
    }
    
    private func stringFromDateIso(_ date: Date) -> String {
        return DateUtils.utcIsoFormatString(from: date)
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
    
    // MARK: - Secrets
    func putDeviceId(_ deviceId: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.deviceId.name, deviceId)
    }
    
    func getDeviceId() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.deviceId.name)
    }
    
    func putAppId(_ appId: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.appId.name, appId)
    }
    
    func getAppId() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.appId.name)
    }
    
    func putUserId(_ userId: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.userId.name, userId)
    }
    
    func getUserId() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.userId.name)
    }
    
    func putUserEmail(_ email: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.userEmail.name, email)
    }
    
    func getUserEmail() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.userEmail.name)
    }
    
    func putSessionId(_ sessionId: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.sessionId.name, sessionId)
    }
    
    func getSessionId() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.sessionId.name)
    }
    
    func putConsumerId(_ consumerId: String) throws {
        try putSecretField(AppSecretsConfiguration.Column.consumerId.name, consumerId)
    }
    
    func getConsumerId() throws -> String? {
        try getSecretField(AppSecretsConfiguration.Column.consumerId.name)
    }
    
    func putLogEvent(_ log: LogEntity) throws {
        try queue.sync {
            let sql = """
            INSERT INTO \(LogEntityConfiguration.tableName)
            (id, appVersion, classFQN, fileName, lineNumber, message, stackTrace, contextJson, type, file, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            bindText(stmt, index: 1, value: log.id)
            bindText(stmt, index: 2, value: log.appVersion)
            bindText(stmt, index: 3, value: log.classFQN)
            bindText(stmt, index: 4, value: log.fileName)
            sqlite3_bind_int64(stmt, 5, log.lineNumber)
            bindText(stmt, index: 6, value: log.message)
            bindText(stmt, index: 7, value: log.stackTrace)
            bindText(stmt, index: 8, value: log.contextJson)
            bindText(stmt, index: 9, value: log.type?.rawValue)
            bindBlob(stmt, index: 10, value: log.file?.data)
            bindText(stmt, index: 11, value: stringFromDateCustom(log.createdAt!))
            
            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw sqliteError
            }
        }
    }
    
    func putLogAnalyticsEvent(_ event: EventEntity) throws {
        try queue.sync {
            let sql = """
                INSERT INTO \(EventEntityConfiguration.tableName)
            (id, data_json, name, createdAt)
            VALUES (?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            bindText(stmt, index: 1, value: event.id)
            bindText(stmt, index: 2, value: event.dataJson)
            bindText(stmt, index: 3, value: event.name)
            bindText(stmt, index: 4, value:  stringFromDateCustom(event.createdAt))
            
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
        }
    }
    
    func getOldest100Logs() throws -> [LogEntity] {
        return try queue.sync {
            var result: [LogEntity] = []
            let sql = """
            SELECT id, appVersion, classFQN, fileName, lineNumber, message, stackTrace,
                   contextJson, type, file, createdAt
            FROM \(LogEntityConfiguration.tableName)
            ORDER BY createdAt ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(stmt, 0) else { continue }
                let id = String(cString: idCStr)
                
                guard
                    let createdAtCStr = sqlite3_column_text(stmt, 10),
                    let createdAt = dateFromStringCustom(String(cString: createdAtCStr))
                else { continue }
                
                let log = LogEntity()
                log.id = id
                log.createdAt = createdAt
                log.appVersion = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }
                log.classFQN = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                let fileName = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }
                log.fileName = fileName
                log.lineNumber = sqlite3_column_int64(stmt, 4)
                log.message = sqlite3_column_text(stmt, 5).flatMap { String(cString: $0) } ?? ""
                log.stackTrace = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) } ?? AppConstants.noStackTraceAvailable
                log.contextJson = sqlite3_column_text(stmt, 7).flatMap { String(cString: $0) } ?? "{}"
                
                if let typeStr = sqlite3_column_text(stmt, 8) {
                    log.type = LogType(rawValue: String(cString: typeStr))
                }
                
                if let fileBlob = sqlite3_column_blob(stmt, 9) {
                    let dataSize = sqlite3_column_bytes(stmt, 9)
                    let data = Data(bytes: fileBlob, count: Int(dataSize))
                    log.file = MultipartFile(
                        fileName: fileName ?? "NA",
                        mimeType: "application/octet-stream",
                        data: data
                    )
                }
                
                result.append(log)
            }
            return result
        }
    }
    
    func getOldest100Events() throws -> [EventEntity] {
        return try queue.sync {
            var result: [EventEntity] = []
            let sql = """
            SELECT id, data_json, name, createdAt
            FROM \(EventEntityConfiguration.tableName)
            ORDER BY createdAt ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw sqliteError
            }
            defer { sqlite3_finalize(stmt) }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(stmt, 0))
                let createdAtString = String(cString: sqlite3_column_text(stmt, 3))
                
                guard let createdAt = dateFromStringCustom(createdAtString) else {
                    continue
                }
                
                let dataJson = String(cString: sqlite3_column_text(stmt, 1))
                let name = String(cString: sqlite3_column_text(stmt, 2))
                
                var metadata: [String: String] = [:]
                if let data = dataJson.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    metadata = dict
                }
            
                let event = EventEntity(
                    id: idString,
                    createdAt: createdAt,
                    name: name,
                    metadata: metadata
                )
                result.append(event)
            }
            return result
        }
    }
    
    func deleteEventList(_ events: [EventEntity]) throws {
        try queue.sync {
            let sql = """
            DELETE FROM \(EventEntityConfiguration.tableName)
            WHERE TRIM(id) = TRIM(?) COLLATE NOCASE;
            """
            var stmt: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw sqliteError
            }
            defer { sqlite3_finalize(stmt) }
            
            for event in events {
                let idString = event.id.trimmingCharacters(in: .whitespacesAndNewlines)
                debugPrint("Attempting to delete event with id: \(idString)")
                
                bindText(stmt, index: 1, value: idString)
                
                let stepResult = sqlite3_step(stmt)
                if stepResult != SQLITE_DONE {
                    debugPrint("sqlite3_step failed for id: \(idString) with result \(stepResult)")
                    throw sqliteError
                } else {
                    debugPrint("Deleted (or did not exist): \(idString)")
                }
                
                sqlite3_reset(stmt)
            }
        }
    }
    
    func deleteLogList(_ logs: [LogEntity]) throws {
        try queue.sync {
            let sql = "DELETE FROM \(LogEntityConfiguration.tableName) WHERE TRIM(id) = TRIM(?) COLLATE NOCASE;"
            var stmt: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            for log in logs {
                guard let id = log.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                    continue
                }
                
                bindText(stmt, index: 1, value: id)
                let stepResult = sqlite3_step(stmt)
                if stepResult != SQLITE_DONE {
                    debugPrint("sqlite3_step returned: \(stepResult) for id \(id)")
                } else {
                    debugPrint("Deleted (or no-op if not found): \(id)")
                }
                
                sqlite3_reset(stmt)
            }
        }
    }
    
    func putSessionData(_ session: SessionData) throws {
        try queue.sync {
            switch session.sessionType! {
            case .start:
                let sql = """
                INSERT INTO \(SessionsConfiguration.tableName)
                (id, sessionId, startSessionDate, endSessionDate)
                VALUES (?, ?, ?, ?);
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(stmt) }
                
                bindText(stmt, index: 1, value: session.id)
                bindText(stmt, index: 2, value: session.sessionId)
                bindText(stmt, index: 3, value: stringFromDateIso(session.timestamp))
                bindText(stmt, index: 4, value: nil)
                
                guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
                
            case .end:
                let selectSQL = """
                SELECT id FROM \(SessionsConfiguration.tableName)
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
                    UPDATE \(SessionsConfiguration.tableName)
                    SET endSessionDate = ?
                    WHERE id = ?;
                    """
                    var updateStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, updateSQL, -1, &updateStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(updateStmt) }
                    
                    bindText(updateStmt, index: 1, value: stringFromDateIso(session.timestamp))
                    bindText(updateStmt, index: 2, value: openId)
                    
                    guard sqlite3_step(updateStmt) == SQLITE_DONE else { throw sqliteError }
                    
                } else {
                    let insertSQL = """
                    INSERT INTO \(SessionsConfiguration.tableName)
                    (id, sessionId, startSessionDate, endSessionDate)
                    VALUES (?, ?, ?, ?);
                    """
                    var insertStmt: OpaquePointer?
                    guard sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK else { throw sqliteError }
                    defer { sqlite3_finalize(insertStmt) }
                    
                    bindText(insertStmt, index: 1, value: session.id)
                    bindText(insertStmt, index: 2, value: session.sessionId)
                    bindText(insertStmt, index: 3, value: nil)
                    bindText(insertStmt, index: 4, value: stringFromDateIso(session.timestamp))
                    
                    guard sqlite3_step(insertStmt) == SQLITE_DONE else { throw sqliteError }
                }
            }
        }
    }
    
    func getOldest100Sessions() throws -> [SessionBatch] {
        return try queue.sync {
            var result: [SessionBatch] = []
            let sql = """
            SELECT id, startSessionDate, endSessionDate
            FROM \(SessionsConfiguration.tableName)
            WHERE (sessionId IS NULL OR sessionId = '')
            AND startSessionDate IS NOT NULL
            AND endSessionDate IS NOT NULL
            ORDER BY startSessionDate ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let startDate = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }.flatMap(dateFromStringIso)
                let endDate = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }.flatMap(dateFromStringIso)

                result.append(SessionBatch(
                    id: id,
                    startedAt: startDate,
                    endedAt: endDate
                ))
            }
            return result
        }
    }

    
    func deleteSessionList(_ sessions: [SessionBatch]) throws {
        try queue.sync {
            let sql = "DELETE FROM \(SessionsConfiguration.tableName) WHERE id = ?;"
            var stmt: OpaquePointer?
            
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            for session in sessions {
                bindText(stmt, index: 1, value: session.id)
                guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
                sqlite3_reset(stmt)
            }
        }
    }
    
    func getSessionById() throws -> SessionData? {
        return try queue.sync {
            let sql = """
            SELECT id, sessionId, startSessionDate, endSessionDate
            FROM \(SessionsConfiguration.tableName)
            WHERE sessionId IS NOT NULL AND sessionId != ''
            LIMIT 1;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let sessionId = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }
                
                if let startStr = sqlite3_column_text(stmt, 2) {
                    if let date = dateFromStringIso(String(cString: startStr)) {
                        return SessionData(
                            id: id,
                            sessionId: sessionId,
                            timestamp: date,
                            sessionType: .start
                        )
                    }
                } else if let endStr = sqlite3_column_text(stmt, 3) {
                    if let date = dateFromStringIso(String(cString: endStr)) {
                        return SessionData(
                            id: id,
                            sessionId: sessionId,
                            timestamp: date,
                            sessionType: .end
                        )
                    }
                }
            }
            return nil
        }
    }
    
    func deleteSessionById(_ idValue: String) throws {
        try queue.sync {
            let sql = "DELETE FROM \(SessionsConfiguration.tableName) WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }
            
            bindText(stmt, index: 1, value: idValue)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
        }
    }

    private func checkSecretExists() throws -> Bool {
        guard let db = self.db else {
            throw NSError(domain: "SQLite3", code: 2, userInfo: [NSLocalizedDescriptionKey: "Database connection is nil or closed"])
        }

        let sql = "SELECT 1 FROM \(AppSecretsConfiguration.tableName) LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw NSError(domain: "SQLite3", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        defer { sqlite3_finalize(stmt) }

        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private func updateSecret(column: String, value: String) throws {
        let sql = "UPDATE \(AppSecretsConfiguration.tableName) SET \(column) = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw sqliteError
        }
        defer { sqlite3_finalize(stmt) }
        
        let nsString = value as NSString
        let cString = nsString.utf8String
        guard sqlite3_bind_text(stmt, 1, cString, -1, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLite3", code: Int(sqlite3_errcode(db)),
                        userInfo: [NSLocalizedDescriptionKey: "Failed to bind text value"])
        }
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw sqliteError
        }
    }

    private func insertSecret(column: String, value: String?) throws {
        let columns = [
            AppSecretsConfiguration.Column.appId.name,
            AppSecretsConfiguration.Column.deviceId.name,
            AppSecretsConfiguration.Column.userId.name,
            AppSecretsConfiguration.Column.userEmail.name,
            AppSecretsConfiguration.Column.sessionId.name,
            AppSecretsConfiguration.Column.consumerId.name
        ]

        let columnNames = columns.joined(separator: ", ")
        let placeholders = columns.map { $0 == column ? "?" : "NULL" }.joined(separator: ", ")
        let sql = "INSERT INTO \(AppSecretsConfiguration.tableName) (\(columnNames)) VALUES (\(placeholders));"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw sqliteError
        }
        defer { sqlite3_finalize(stmt) }

        if let index = columns.firstIndex(of: column) {
            bindText(stmt, index: Int32(index + 1), value: value)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw sqliteError
        }
    }

    private func getSecret(column: String) throws -> String? {
        let sql = "SELECT \(column) FROM \(AppSecretsConfiguration.tableName) LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw sqliteError
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                return String(cString: cString)
            }
        }
        return nil
    }
    
    private func putSecretField(_ column: String, _ value: String) throws {
        try queue.sync {
            let isEmpty = try !checkSecretExists()
            
            if isEmpty {
                try insertSecret(column: column, value: value)
            } else {
                try updateSecret(column: column, value: value)
            }
        }
    }

    private func getSecretField(_ column: String) throws -> String? {
        return try queue.sync {
            try getSecret(column: column)
        }
    }
}
