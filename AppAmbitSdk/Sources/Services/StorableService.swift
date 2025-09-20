import Foundation
import SQLite3

final class StorableService: StorageService {
    private let db: OpaquePointer?

    private let queue = Queues.db
    private let queueKey = DispatchSpecificKey<UInt8>()
    private let queueFlag: UInt8 = 1
    private func syncOnQueue<T>(_ body: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) == queueFlag { return try body() }
        return try queue.sync(execute: body)
    }

    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(ds: DataStore) throws {
        var tmpDb: OpaquePointer?
        let result = sqlite3_open(ds.dbPath, &tmpDb)
        guard result == SQLITE_OK else {
            throw NSError(domain: "DataStore", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }
        self.db = tmpDb
        queue.setSpecific(key: queueKey, value: queueFlag)
    }

    private func dateFromStringCustom(_ value: String) -> Date? {
        DateUtils.utcCustomFormatDate(from: value)
    }

    private func stringFromDateCustom(_ date: Date) -> String {
        DateUtils.utcCustomFormatString(from: date)
    }

    private func dateFromStringIso(_ value: String) -> Date? {
        DateUtils.utcIsoFormatDate(from: value)
    }

    private func stringFromDateIso(_ date: Date) -> String {
        DateUtils.utcIsoFormatString(from: date)
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

    func putDeviceId(_ deviceId: String) throws { try putSecretField(AppSecretsConfiguration.Column.deviceId.name, deviceId) }
    func getDeviceId() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.deviceId.name) }

    func putAppId(_ appId: String) throws { try putSecretField(AppSecretsConfiguration.Column.appId.name, appId) }
    func getAppId() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.appId.name) }

    func putUserId(_ userId: String) throws { try putSecretField(AppSecretsConfiguration.Column.userId.name, userId) }
    func getUserId() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.userId.name) }

    func putUserEmail(_ email: String) throws { try putSecretField(AppSecretsConfiguration.Column.userEmail.name, email) }
    func getUserEmail() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.userEmail.name) }

    func putSessionId(_ sessionId: String) throws { try putSecretField(AppSecretsConfiguration.Column.sessionId.name, sessionId) }
    func getSessionId() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.sessionId.name) }

    func putConsumerId(_ consumerId: String) throws { try putSecretField(AppSecretsConfiguration.Column.consumerId.name, consumerId) }
    func getConsumerId() throws -> String? { try getSecretField(AppSecretsConfiguration.Column.consumerId.name) }

    // MARK: - Logs

    func putLogEvent(_ log: LogEntity) throws {
        try syncOnQueue {
            let sql = """
            INSERT INTO \(LogEntityConfiguration.tableName)
            (\(LogEntityConfiguration.Column.id.name), \(LogEntityConfiguration.Column.sessionId.name),
             \(LogEntityConfiguration.Column.appVersion.name), \(LogEntityConfiguration.Column.classFQN.name),
             \(LogEntityConfiguration.Column.fileName.name), \(LogEntityConfiguration.Column.lineNumber.name),
             \(LogEntityConfiguration.Column.message.name), \(LogEntityConfiguration.Column.stackTrace.name),
             \(LogEntityConfiguration.Column.contextJson.name), \(LogEntityConfiguration.Column.type.name),
             \(LogEntityConfiguration.Column.file.name), \(LogEntityConfiguration.Column.createdAt.name))
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, value: log.id)
            bindText(stmt, index: 2, value: log.sessionId)
            bindText(stmt, index: 3, value: log.appVersion)
            bindText(stmt, index: 4, value: log.classFQN)
            bindText(stmt, index: 5, value: log.fileName)
            sqlite3_bind_int64(stmt, 6, log.lineNumber)
            bindText(stmt, index: 7, value: log.message)
            bindText(stmt, index: 8, value: log.stackTrace)
            bindText(stmt, index: 9, value: log.contextJson)
            bindText(stmt, index: 10, value: log.type?.rawValue)
            bindBlob(stmt, index: 11, value: log.file?.data)
            bindText(stmt, index: 12, value: stringFromDateCustom(log.createdAt!))

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
        }
    }

    func getOldest100Logs() throws -> [LogEntity] {
        try syncOnQueue {
            var result: [LogEntity] = []
            let sql = """
            SELECT \(LogEntityConfiguration.Column.id.name), \(LogEntityConfiguration.Column.sessionId.name),
                   \(LogEntityConfiguration.Column.appVersion.name), \(LogEntityConfiguration.Column.classFQN.name),
                   \(LogEntityConfiguration.Column.fileName.name), \(LogEntityConfiguration.Column.lineNumber.name),
                   \(LogEntityConfiguration.Column.message.name), \(LogEntityConfiguration.Column.stackTrace.name),
                   \(LogEntityConfiguration.Column.contextJson.name), \(LogEntityConfiguration.Column.type.name),
                   \(LogEntityConfiguration.Column.file.name), \(LogEntityConfiguration.Column.createdAt.name)
            FROM \(LogEntityConfiguration.tableName)
            ORDER BY \(LogEntityConfiguration.Column.createdAt.name) ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idCStr = sqlite3_column_text(stmt, 0) else { continue }
                let id = String(cString: idCStr)

                guard
                    let createdAtCStr = sqlite3_column_text(stmt, 11),
                    let createdAt = dateFromStringCustom(String(cString: createdAtCStr))
                else { continue }

                let log = LogEntity()
                log.id = id
                log.sessionId = sqlite3_column_text(stmt, 1).flatMap { String(cString: $0) }
                log.createdAt = createdAt
                log.appVersion = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }
                log.classFQN = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }
                let fileName = sqlite3_column_text(stmt, 4).flatMap { String(cString: $0) }
                log.fileName = fileName
                log.lineNumber = sqlite3_column_int64(stmt, 5)
                log.message = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) } ?? ""
                log.stackTrace = sqlite3_column_text(stmt, 7).flatMap { String(cString: $0) } ?? AppConstants.noStackTraceAvailable
                log.contextJson = sqlite3_column_text(stmt, 8).flatMap { String(cString: $0) } ?? "{}"

                if let typeStr = sqlite3_column_text(stmt, 9) {
                    log.type = LogType(rawValue: String(cString: typeStr))
                }

                if let fileBlob = sqlite3_column_blob(stmt, 10) {
                    let dataSize = sqlite3_column_bytes(stmt, 10)
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

    func deleteLogList(_ logs: [LogEntity]) throws {
        try syncOnQueue {
            let sql = "DELETE FROM \(LogEntityConfiguration.tableName) WHERE TRIM(\(LogEntityConfiguration.Column.id.name)) = TRIM(?) COLLATE NOCASE;"
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
                }

                sqlite3_reset(stmt)
            }
        }
    }

    // MARK: - Events

    func putLogAnalyticsEvent(_ event: EventEntity) throws {
        try syncOnQueue {
            let sql = """
            INSERT INTO \(EventEntityConfiguration.tableName)
            (\(EventEntityConfiguration.Column.id.name), \(EventEntityConfiguration.Column.sessionId.name),
             \(EventEntityConfiguration.Column.dataJson.name), \(EventEntityConfiguration.Column.name.name),
             \(EventEntityConfiguration.Column.createdAt.name))
            VALUES (?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, value: event.id)
            bindText(stmt, index: 2, value: event.sessionId)
            bindText(stmt, index: 3, value: event.dataJson)
            bindText(stmt, index: 4, value: event.name)
            bindText(stmt, index: 5, value: stringFromDateCustom(event.createdAt))

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
        }
    }

    func getOldest100Events() throws -> [EventEntity] {
        try syncOnQueue {
            var result: [EventEntity] = []
            let sql = """
            SELECT
                \(EventEntityConfiguration.Column.id.name), \(EventEntityConfiguration.Column.sessionId.name),
                \(EventEntityConfiguration.Column.dataJson.name), \(EventEntityConfiguration.Column.name.name),
                \(EventEntityConfiguration.Column.createdAt.name)
            FROM \(EventEntityConfiguration.tableName)
            ORDER BY \(EventEntityConfiguration.Column.createdAt.name) ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw sqliteError
            }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let idString = String(cString: sqlite3_column_text(stmt, 0))
                let sessionId = String(cString: sqlite3_column_text(stmt, 1))
                let dataJson = String(cString: sqlite3_column_text(stmt, 2))
                let name = String(cString: sqlite3_column_text(stmt, 3))
                let createdAtString = String(cString: sqlite3_column_text(stmt, 4))

                guard let createdAt = dateFromStringCustom(createdAtString) else { continue }

                var metadata: [String: String] = [:]
                if let data = dataJson.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    metadata = dict
                }

                let event = EventEntity(
                    id: idString,
                    sessionId: sessionId,
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
        try syncOnQueue {
            let sql = """
            DELETE FROM \(EventEntityConfiguration.tableName)
            WHERE TRIM(\(EventEntityConfiguration.Column.id.name)) = TRIM(?) COLLATE NOCASE;
            """
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw sqliteError
            }
            defer { sqlite3_finalize(stmt) }

            for event in events {
                let idString = event.id.trimmingCharacters(in: .whitespacesAndNewlines)

                bindText(stmt, index: 1, value: idString)

                let stepResult = sqlite3_step(stmt)
                if stepResult != SQLITE_DONE {
                    debugPrint("sqlite3_step failed for id: \(idString) with result \(stepResult)")
                    throw sqliteError
                }

                sqlite3_reset(stmt)
            }
        }
    }

    // MARK: - Sessions

    func updateLogsAndEventsSessionIds(_ sessions: [SessionBatch]) throws {
        guard !sessions.isEmpty else { return }

        try syncOnQueue {
            let logsTable = LogEntityConfiguration.tableName
            let logsCol   = LogEntityConfiguration.Column.sessionId.name
            let evtsTable = EventEntityConfiguration.tableName
            let evtsCol   = EventEntityConfiguration.Column.sessionId.name

            let sqlLogs = """
            UPDATE \(logsTable)
            SET \(logsCol) = TRIM(?)
            WHERE TRIM(\(logsCol)) = TRIM(?) COLLATE NOCASE;
            """

            let sqlEvents = """
            UPDATE \(evtsTable)
            SET \(evtsCol) = TRIM(?)
            WHERE TRIM(\(evtsCol)) = TRIM(?) COLLATE NOCASE;
            """

            var stmtLogs: OpaquePointer?
            var stmtEvts: OpaquePointer?

            guard sqlite3_prepare_v2(db, sqlLogs, -1, &stmtLogs, nil) == SQLITE_OK,
                  sqlite3_prepare_v2(db, sqlEvents, -1, &stmtEvts, nil) == SQLITE_OK else {
                throw sqliteError
            }
            defer {
                sqlite3_finalize(stmtLogs)
                sqlite3_finalize(stmtEvts)
            }

            guard sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError
            }
            var mustRollback = true
            defer {
                if mustRollback {
                    _ = sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
                }
            }

            var seen = Set<String>() // clave: "\(old.lowercased())\u{1F}\(new.lowercased())"

            for s in sessions {
                let oldRaw = s.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !oldRaw.isEmpty else { continue }

                guard let newRaw0 = s.sessionId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !newRaw0.isEmpty else { continue }

                if oldRaw.compare(newRaw0, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                    continue
                }

                let key = oldRaw.lowercased() + "\u{001F}" + newRaw0.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)

                bindText(stmtLogs, index: 1, value: newRaw0)
                bindText(stmtLogs, index: 2, value: oldRaw)
                let rc1 = sqlite3_step(stmtLogs)
                if rc1 != SQLITE_DONE {
                    debugPrint("sqlite3_step LOGS rc=\(rc1)  \(oldRaw) -> \(newRaw0)")
                }
                
                sqlite3_reset(stmtLogs)
                sqlite3_clear_bindings(stmtLogs)
                
                bindText(stmtEvts, index: 1, value: newRaw0)
                bindText(stmtEvts, index: 2, value: oldRaw)
                let rc2 = sqlite3_step(stmtEvts)
                if rc2 != SQLITE_DONE {
                    debugPrint("sqlite3_step EVENTS rc=\(rc2)  \(oldRaw) -> \(newRaw0)")
                }
                
                sqlite3_reset(stmtEvts)
                sqlite3_clear_bindings(stmtEvts)
            }

            guard sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK else {
                throw sqliteError
            }
            
            mustRollback = false
        }
    }

    func getUnpairedSessionStart() throws -> SessionData? {
        try syncOnQueue {
            let sql = """
            SELECT
              \(SessionsConfiguration.Column.id.name),
              \(SessionsConfiguration.Column.sessionId.name),
              \(SessionsConfiguration.Column.startedAt.name),
              \(SessionsConfiguration.Column.endedAt.name)
            FROM \(SessionsConfiguration.tableName)
            WHERE NULLIF(TRIM(\(SessionsConfiguration.Column.startedAt.name)), '') IS NOT NULL
              AND NULLIF(TRIM(\(SessionsConfiguration.Column.endedAt.name)), '') IS NULL
            ORDER BY \(SessionsConfiguration.Column.endedAt.name) ASC
            LIMIT 1;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return nil
            }

            let id = String(cString: sqlite3_column_text(stmt, 0))

            let sessionId: String? = {
                guard let ptr = sqlite3_column_text(stmt, 1) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : s
            }()

            let startedAt: Date? = {
                guard let ptr = sqlite3_column_text(stmt, 2) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : dateFromStringIso(s)
            }()

            let endedAt: Date? = {
                guard let ptr = sqlite3_column_text(stmt, 3) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : dateFromStringIso(s)
            }()

            if let d = startedAt {
                return SessionData(id: id, sessionId: sessionId, timestamp: d, sessionType: .start)
            }

            if let d = endedAt {
                return SessionData(id: id, sessionId: sessionId, timestamp: d, sessionType: .end)
            }

            return nil
        }
    }
    
    func getUnpairedSessionEnd() throws -> SessionData? {
        try syncOnQueue {
            let sql = """
            SELECT
              \(SessionsConfiguration.Column.id.name),
              \(SessionsConfiguration.Column.sessionId.name),
              \(SessionsConfiguration.Column.startedAt.name),
              \(SessionsConfiguration.Column.endedAt.name)
            FROM \(SessionsConfiguration.tableName)
            WHERE NULLIF(TRIM(\(SessionsConfiguration.Column.startedAt.name)), '') IS NULL
              AND NULLIF(TRIM(\(SessionsConfiguration.Column.endedAt.name)), '') IS NOT NULL
            ORDER BY \(SessionsConfiguration.Column.endedAt.name) ASC
            LIMIT 1;
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_step(stmt) == SQLITE_ROW else {
                return nil
            }

            let id = String(cString: sqlite3_column_text(stmt, 0))

            let sessionId: String? = {
                guard let ptr = sqlite3_column_text(stmt, 1) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : s
            }()

            let startedAt: Date? = {
                guard let ptr = sqlite3_column_text(stmt, 2) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : dateFromStringIso(s)
            }()

            let endedAt: Date? = {
                guard let ptr = sqlite3_column_text(stmt, 3) else { return nil }
                let s = String(cString: ptr)
                return s.isEmpty ? nil : dateFromStringIso(s)
            }()

            if let d = startedAt {
                return SessionData(id: id, sessionId: sessionId, timestamp: d, sessionType: .start)
            }

            if let d = endedAt {
                return SessionData(id: id, sessionId: sessionId, timestamp: d, sessionType: .end)
            }

            return nil
        }
    }

    func putSessionData(_ session: SessionData) throws {
        try syncOnQueue {
            switch session.sessionType! {
            case .start:
                do {
                    let selectOpenSQL = """
                    SELECT \(SessionsConfiguration.Column.id.name)
                    FROM \(SessionsConfiguration.tableName)
                    WHERE \(SessionsConfiguration.Column.endedAt.name) IS NULL
                    ORDER BY \(SessionsConfiguration.Column.startedAt.name) ASC
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
                        UPDATE \(SessionsConfiguration.tableName)
                        SET \(SessionsConfiguration.Column.endedAt.name) = ?
                        WHERE \(SessionsConfiguration.Column.id.name) = ?;
                        """
                        var closeStmt: OpaquePointer?
                        guard sqlite3_prepare_v2(db, closeSQL, -1, &closeStmt, nil) == SQLITE_OK else { throw sqliteError }
                        defer { sqlite3_finalize(closeStmt) }

                        bindText(closeStmt, index: 1, value: stringFromDateIso(session.timestamp))
                        bindText(closeStmt, index: 2, value: openId)

                        guard sqlite3_step(closeStmt) == SQLITE_DONE else { throw sqliteError }
                    }
                }

                let insertStartSQL = """
                INSERT INTO \(SessionsConfiguration.tableName)
                (\(SessionsConfiguration.Column.id.name), \(SessionsConfiguration.Column.sessionId.name),
                 \(SessionsConfiguration.Column.startedAt.name), \(SessionsConfiguration.Column.endedAt.name))
                VALUES (?, ?, ?, ?);
                """
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, insertStartSQL, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(stmt) }

                bindText(stmt, index: 1, value: session.id)
                bindText(stmt, index: 2, value: session.sessionId)
                bindText(stmt, index: 3, value: stringFromDateIso(session.timestamp))
                bindText(stmt, index: 4, value: nil)

                guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }

            case .end:
                let selectSQL = """
                SELECT \(SessionsConfiguration.Column.id.name) FROM \(SessionsConfiguration.tableName)
                WHERE \(SessionsConfiguration.Column.endedAt.name) IS NULL
                ORDER BY \(SessionsConfiguration.Column.startedAt.name) ASC
                LIMIT 1;
                """
                var selectStmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, selectSQL, -1, &selectStmt, nil) == SQLITE_OK else { throw sqliteError }
                defer { sqlite3_finalize(selectStmt) }

                var foundId: String? = nil
                if sqlite3_step(selectStmt) == SQLITE_ROW, let idCStr = sqlite3_column_text(selectStmt, 0) {
                    foundId = String(cString: idCStr)
                }

                if let openId = foundId {
                    let updateSQL = """
                    UPDATE \(SessionsConfiguration.tableName)
                    SET \(SessionsConfiguration.Column.endedAt.name) = ?
                    WHERE \(SessionsConfiguration.Column.id.name) = ?;
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
                    (\(SessionsConfiguration.Column.id.name), \(SessionsConfiguration.Column.sessionId.name),
                     \(SessionsConfiguration.Column.startedAt.name), \(SessionsConfiguration.Column.endedAt.name))
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
        try syncOnQueue {
            var result: [SessionBatch] = []
            let sql = """
            SELECT
                \(SessionsConfiguration.Column.id.name), \(SessionsConfiguration.Column.sessionId.name),
                \(SessionsConfiguration.Column.startedAt.name), \(SessionsConfiguration.Column.endedAt.name)
            FROM \(SessionsConfiguration.tableName)
            WHERE \(SessionsConfiguration.Column.startedAt.name) IS NOT NULL
              AND \(SessionsConfiguration.Column.endedAt.name) IS NOT NULL
            ORDER BY \(SessionsConfiguration.Column.startedAt.name) ASC
            LIMIT 100;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let sessionId = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 1)) : nil
                let startDate = sqlite3_column_text(stmt, 2).flatMap { String(cString: $0) }.flatMap(dateFromStringIso)
                let endDate = sqlite3_column_text(stmt, 3).flatMap { String(cString: $0) }.flatMap(dateFromStringIso)

                result.append(SessionBatch(
                    id: id,
                    sessionId: sessionId,
                    startedAt: startDate,
                    endedAt: endDate
                ))
            }
            return result
        }
    }

    func deleteSessionList(_ sessions: [SessionBatch]) throws {
        try syncOnQueue {
            let sql = "DELETE FROM \(SessionsConfiguration.tableName) WHERE \(SessionsConfiguration.Column.id.name) = ?;"
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

    func deleteSessionById(_ idValue: String) throws {
        try syncOnQueue {
            let sql = "DELETE FROM \(SessionsConfiguration.tableName) WHERE \(SessionsConfiguration.Column.id.name) = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw sqliteError }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, value: idValue)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw sqliteError }
        }
    }

    // MARK: - Secrets table internals

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
        try syncOnQueue {
            let isEmpty = try !checkSecretExists()
            if isEmpty {
                try insertSecret(column: column, value: value)
            } else {
                try updateSecret(column: column, value: value)
            }
        }
    }

    private func getSecretField(_ column: String) throws -> String? {
        try syncOnQueue {
            try getSecret(column: column)
        }
    }
}
