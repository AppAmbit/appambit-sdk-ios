import Foundation
import SQLite

final class DataStore {
    let db: Connection

    init() throws {
        let fileURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("\(AppConstants.databaseFileName).sqlite")

        print("Database: ", fileURL.path)

        db = try Connection(fileURL.path)

        try createTables()
    }

    private func createTables() throws {
        try db.run(AppSecretsConfiguration.createTable)
        try db.run(SessionsConfiguration.createTable)
        try db.run(LogEntityConfiguration.createTable)
        try db.run(EventEntityConfiguration.createTable)
    }
}
