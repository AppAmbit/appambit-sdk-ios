import Foundation
import SQLite


class Storable: StoragaService {
    private let db: Connection
    private let queue = DispatchQueue(label: "com.appambit.storage.service", qos: .utility)

    private let secrets = Table(AppSecretsConfiguration.tableName)
    private let logs = Table(LogEntityConfiguration.tableName)
    private let events = Table(EventEntityConfiguration.tableName)
    private let sessions = Table(SessionsConfiguration.tableName)

    init(ds: DataStore) throws {
        db = ds.db;
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

    func putDeviceId(_ deviceId: String) throws {
        try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if try db.pluck(query) != nil {
                try db.run(query.update(
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.deviceId.name) <- deviceId
                ))
            } else {
                try db.run(secrets.insert(
                    SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) <- rowId,
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.deviceId.name) <- deviceId
                ))
            }
        }
    }

    func getDeviceId() throws -> String? {
        return try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if let row = try db.pluck(query) {
                return row[SQLite.Expression<String?>(AppSecretsConfiguration.Column.deviceId.name)]
            }
            return nil
        }
    }

    func putAppId(_ appId: String) throws {
        try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if try db.pluck(query) != nil {
                try db.run(query.update(
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.appId.name) <- appId
                ))
            } else {
                try db.run(secrets.insert(
                    SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) <- rowId,
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.appId.name) <- appId
                ))
            }
        }
    }

    func getAppId() throws -> String? {
        return try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if let row = try db.pluck(query) {
                return row[SQLite.Expression<String?>(AppSecretsConfiguration.Column.appId.name)]
            }
            return nil
        }
    }

    func putUserId(_ userId: String) throws {
        try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if try db.pluck(query) != nil {
                try db.run(query.update(
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.userId.name) <- userId
                ))
            } else {
                try db.run(secrets.insert(
                    SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) <- rowId,
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.userId.name) <- userId
                ))
            }
        }
    }

    func getUserId() throws -> String? {
        return try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if let row = try db.pluck(query) {
                return row[SQLite.Expression<String?>(AppSecretsConfiguration.Column.userId.name)]
            }
            return nil
        }
    }

    func putUserEmail(_ email: String) throws {
        try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if try db.pluck(query) != nil {
                try db.run(query.update(
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.userEmail.name) <- email
                ))
            } else {
                try db.run(secrets.insert(
                    SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) <- rowId,
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.userEmail.name) <- email
                ))
            }
        }
    }

    func getUserEmail() throws -> String? {
        return try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if let row = try db.pluck(query) {
                return row[SQLite.Expression<String?>(AppSecretsConfiguration.Column.userEmail.name)]
            }
            return nil
        }
    }

    func putSessionId(_ sessionId: String) throws {
        try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if try db.pluck(query) != nil {
                try db.run(query.update(
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.sessionId.name) <- sessionId
                ))
            } else {
                try db.run(secrets.insert(
                    SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) <- rowId,
                    SQLite.Expression<String?>(AppSecretsConfiguration.Column.sessionId.name) <- sessionId
                ))
            }
        }
    }

    func getSessionId() throws -> String? {
        return try queue.sync {
            let rowId = "1"
            let query = secrets.filter(SQLite.Expression<String>(AppSecretsConfiguration.Column.id.name) == rowId)
            if let row = try db.pluck(query) {
                return row[SQLite.Expression<String?>(AppSecretsConfiguration.Column.sessionId.name)]
            }
            return nil
        }
    }

    func putLogEvent(_ log: LogEntity) throws {
        queue.sync {
            do {
                let insert = logs.insert(or: .replace,
                    SQLite.Expression<String>(LogEntityConfiguration.Column.id.name) <- log.id,
                    SQLite.Expression<String?>(LogEntityConfiguration.Column.appVersion.name) <- log.appVersion,
                    SQLite.Expression<String?>(LogEntityConfiguration.Column.classFQN.name) <- log.classFQN,
                    SQLite.Expression<String?>(LogEntityConfiguration.Column.fileName.name) <- log.fileName,
                    SQLite.Expression<Int64>(LogEntityConfiguration.Column.lineNumber.name) <- log.lineNumber,
                    SQLite.Expression<String>(LogEntityConfiguration.Column.message.name) <- log.message,
                    SQLite.Expression<String>(LogEntityConfiguration.Column.stackTrace.name) <- log.stackTrace,
                    SQLite.Expression<String>(LogEntityConfiguration.Column.contextJson.name) <- log.contextJson,
                    SQLite.Expression<String?>(LogEntityConfiguration.Column.type.name) <- log.type?.rawValue,
                    SQLite.Expression<String>(LogEntityConfiguration.Column.createdAt.name) <- stringFromDateCustom(log.createdAt)
                )
                try db.run(insert)
            } catch {
                print("Error putting log event: \(error)")
            }
        }
    }

    func getOldest100Logs() throws -> [LogEntity] {
        return try queue.sync {
            let table = logs.order(SQLite.Expression<String>(LogEntityConfiguration.Column.createdAt.name).asc).limit(100)
            var result = [LogEntity]()
            
            let idExp = SQLite.Expression<String>(LogEntityConfiguration.Column.id.name)
            let appVersionExp = SQLite.Expression<String?>(LogEntityConfiguration.Column.appVersion.name)
            let classFQNExp = SQLite.Expression<String?>(LogEntityConfiguration.Column.classFQN.name)
            let fileNameExp = SQLite.Expression<String?>(LogEntityConfiguration.Column.fileName.name)
            let lineNumberExp = SQLite.Expression<Int64>(LogEntityConfiguration.Column.lineNumber.name)
            let messageExp = SQLite.Expression<String>(LogEntityConfiguration.Column.message.name)
            let stackTraceExp = SQLite.Expression<String>(LogEntityConfiguration.Column.stackTrace.name)
            let contextJsonExp = SQLite.Expression<String>(LogEntityConfiguration.Column.contextJson.name)
            let typeExp = SQLite.Expression<String?>(LogEntityConfiguration.Column.type.name)
            let createdAtExp = SQLite.Expression<String>(LogEntityConfiguration.Column.createdAt.name)
            
            for row in try db.prepare(table) {
                let log = LogEntity()
                log.id = row[idExp]
                log.appVersion = row[appVersionExp]
                log.classFQN = row[classFQNExp]
                log.fileName = row[fileNameExp]
                log.lineNumber = row[lineNumberExp]
                log.message = row[messageExp]
                log.stackTrace = row[stackTraceExp]
                log.contextJson = row[contextJsonExp]
                if let typeValue = row[typeExp] {
                    log.type = LogType(rawValue: typeValue)
                }
                 
                if let createdAt = dateFromStringCustom(row[createdAtExp]) {
                    log.createdAt = createdAt
                }
                
                result.append(log)
            }
            return result
        }
    }

    func deleteLogList(_ logs: [LogEntity]) throws {
        queue.sync {
            do {
                for log in logs {
                    let row = self.logs.filter(SQLite.Expression<String>(LogEntityConfiguration.Column.id.name) == log.id)
                    try db.run(row.delete())
                }
            } catch {
                print("Error deleting logs: \(error)")
            }
        }
    }

    func putLogAnalyticsEvent(_ event: EventEntity) throws {
        queue.sync {
            do {
                let insert = events.insert(or: .replace,
                    SQLite.Expression<String>(EventEntityConfiguration.Column.id.name) <- event.id.uuidString,
                    SQLite.Expression<String>(EventEntityConfiguration.Column.dataJson.name) <- event.dataJson,
                    SQLite.Expression<String>(EventEntityConfiguration.Column.name.name) <- event.name,
                    SQLite.Expression<String>(EventEntityConfiguration.Column.createdAt.name) <- stringFromDateCustom(event.createdAt)
                )
                try db.run(insert)
            } catch {
                print("Error putting analytics event: \(error)")
            }
        }
    }

    func getOldest100Events() throws -> [EventEntity] {
        return try queue.sync {
            let table = events.order(SQLite.Expression<String>(EventEntityConfiguration.Column.createdAt.name).asc).limit(100)
            var result = [EventEntity]()
            
            let idExp = SQLite.Expression<String>(EventEntityConfiguration.Column.id.name)
            let dataJsonExp = SQLite.Expression<String>(EventEntityConfiguration.Column.dataJson.name)
            let nameExp = SQLite.Expression<String>(EventEntityConfiguration.Column.name.name)
            let createdAtExp = SQLite.Expression<String>(EventEntityConfiguration.Column.createdAt.name)
            
            for row in try db.prepare(table) {
                guard let uuid = UUID(uuidString: row[idExp]),
                      let date = dateFromStringCustom(row[createdAtExp]) else {
                    continue
                }
                
                var metadata: [String: String] = [:]
                if let data = row[dataJsonExp].data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    metadata = dict
                }
                
                let event = EventEntity(
                    id: uuid,
                    createdAt: date,
                    name: row[nameExp],
                    metadata: metadata
                )
                result.append(event)
            }
            return result
        }
    }

    func deleteEventList(_ events: [EventEntity]) throws {
        queue.sync {
            do {
                for event in events {
                    let row = self.events.filter(SQLite.Expression<String>(EventEntityConfiguration.Column.id.name) == event.id.uuidString)
                    try db.run(row.delete())
                }
            } catch {
                print("Error deleting events: \(error)")
            }
        }
    }

    func putSessionData(_ session: SessionData) throws {
        try queue.sync {
            switch session.sessionType {
            case .start:
                let insert = sessions.insert(
                    SQLite.Expression<String>(SessionsConfiguration.Column.id.name) <- session.id,
                    SQLite.Expression<String?>(SessionsConfiguration.Column.sessionId.name) <- session.sessionId,
                    SQLite.Expression<String?>(SessionsConfiguration.Column.startSessionDate.name) <- stringFromDateIso(session.timestamp),
                    SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name) <- nil
                )
                try db.run(insert)

            case .end:
                let filter = sessions
                    .filter(SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name) == nil)
                    .order(SQLite.Expression<String?>(SessionsConfiguration.Column.startSessionDate.name).desc)
                    .limit(1)

                if let row = try db.pluck(filter) {
                    let rowId = SQLite.Expression<String>(SessionsConfiguration.Column.id.name)
                    let update = sessions
                        .filter(rowId == row[rowId])
                        .update(
                            SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name) <- stringFromDateIso(session.timestamp)
                        )
                    try db.run(update)

                } else {

                    let insert = sessions.insert(
                        SQLite.Expression<String>(SessionsConfiguration.Column.id.name) <- session.id,
                        SQLite.Expression<String?>(SessionsConfiguration.Column.sessionId.name) <- session.sessionId,
                        SQLite.Expression<String?>(SessionsConfiguration.Column.startSessionDate.name) <- nil,
                        SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name) <- stringFromDateIso(session.timestamp)
                    )
                    try db.run(insert)
                }
            }
        }
    }


    func getOldest100Sessions() throws -> [SessionBatch] {
        return try queue.sync {
            let idExp = SQLite.Expression<String>(SessionsConfiguration.Column.id.name)
            let sessionIdExp = SQLite.Expression<String?>(SessionsConfiguration.Column.sessionId.name)
            let startDateExp = SQLite.Expression<String?>(SessionsConfiguration.Column.startSessionDate.name)
            let endDateExp = SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name)

            let query = sessions
                .filter(sessionIdExp == nil || sessionIdExp == "")
                .order(startDateExp.asc)
                .limit(100)

            var result: [SessionBatch] = []

            for row in try db.prepare(query) {
                let id = row[idExp]
                let startedAt = row[startDateExp].flatMap { dateFromStringIso($0) }
                let endedAt = row[endDateExp].flatMap { dateFromStringIso($0) }

                result.append(SessionBatch(
                    id: id,
                    startedAt: startedAt,
                    endedAt: endedAt
                ))
            }

            return result
        }
    }


    func deleteSessionList(_ sessions: [SessionBatch]) throws {
        try queue.sync {
            do {
                for session in sessions {
                    let row = self.sessions.filter(SQLite.Expression<String>(SessionsConfiguration.Column.id.name) == session.id)
                    try db.run(row.delete())
                }
            } catch {
                print("Error deleting sessions: \(error)")
                throw error
            }
        }
    }

    
    func getFirstSessionWithSessionId() throws -> SessionData? {
        return try queue.sync {
            let idExp = SQLite.Expression<String>(SessionsConfiguration.Column.id.name)
            let sessionIdExp = SQLite.Expression<String?>(SessionsConfiguration.Column.sessionId.name)
            let startDateExp = SQLite.Expression<String?>(SessionsConfiguration.Column.startSessionDate.name)
            let endDateExp = SQLite.Expression<String?>(SessionsConfiguration.Column.endSessionDate.name)

            let query = sessions
                .filter(sessionIdExp != nil)
                .limit(1)

            if let row = try db.pluck(query) {
                let id = row[idExp]
                let sessionId = row[sessionIdExp]

                if let startDateStr = row[startDateExp],
                   let startDate = dateFromStringIso(startDateStr) {
                    return SessionData(
                        id: id,
                        sessionId: sessionId,
                        timestamp: startDate,
                        sessionType: .start
                    )
                } else if let endDateStr = row[endDateExp],
                          let endDate = dateFromStringIso(endDateStr) {
                    return SessionData(
                        id: id,
                        sessionId: sessionId,
                        timestamp: endDate,
                        sessionType: .end
                    )
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    func deleteSessionById(_ idValue: String) throws {
        try queue.sync {
            let idExp = SQLite.Expression<String>(SessionsConfiguration.Column.id.name)
            let record = sessions.filter(idExp == idValue)
            try db.run(record.delete())
        }
    }

}
