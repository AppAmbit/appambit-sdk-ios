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
        debugPrint("Database path: \(dbPath)")

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
        try exec(BreadcrumbEntityConfiguration.createTable)
        try exec(RemoteConfigEntityConfiguration.createTable)
        try exec(CmsCacheConfiguration.createTable)
        
        // Migrate existing secrets table to add push notification columns if they don't exist
        migrateSecretsTable()
    }
    
    private func migrateSecretsTable() {
        // Check and add deviceToken column if it doesn't exist
        if !columnExists(table: "secrets", column: "deviceToken") {
            try? exec("ALTER TABLE secrets ADD COLUMN deviceToken TEXT")
        }
        
        // Check and add pushEnabled column if it doesn't exist
        if !columnExists(table: "secrets", column: "pushEnabled") {
            try? exec("ALTER TABLE secrets ADD COLUMN pushEnabled INTEGER DEFAULT 1")
        }
    }
    
    private func columnExists(table: String, column: String) -> Bool {
        let query = "PRAGMA table_info(\(table))"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let columnName = sqlite3_column_text(statement, 1) {
                let name = String(cString: columnName)
                if name == column {
                    return true
                }
            }
        }
        
        return false
    }
}
