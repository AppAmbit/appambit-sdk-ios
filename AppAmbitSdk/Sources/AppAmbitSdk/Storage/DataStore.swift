import Foundation
import SQLite3

final class DataStore {
    let dbPath: String
    var db: OpaquePointer?

    init() throws {
        let fileURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("\(AppConstants.databaseFileName).sqlite")
        
        dbPath = fileURL.path
        print("Database path: \(dbPath)")

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw NSError(domain: "DataStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }

        try createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let message = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw NSError(domain: "DataStore", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func createTables() throws {
        try exec(AppSecretsConfiguration.createTable)
        try exec(SessionsConfiguration.createTable)
        try exec(LogEntityConfiguration.createTable)
        try exec(EventEntityConfiguration.createTable)
    }
}
