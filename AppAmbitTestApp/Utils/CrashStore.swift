import Foundation

enum CrashStoreError: Error {
    case appSupportNotFound
    case directoryMissing(URL)
}

struct CrashStore {

    private static func crashLogsDirectory() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { throw CrashStoreError.appSupportNotFound }
        return base.appendingPathComponent("CrashLogs")
    }

    static func loadAll() throws -> [ExceptionModel] {
        let dir = try crashLogsDirectory()
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw CrashStoreError.directoryMissing(dir)
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var items: [ExceptionModel] = []
        items.reserveCapacity(urls.count)

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let info = try decoder.decode(ExceptionModel.self, from: data)
                items.append(info)
            } catch {
                debugPrint("[CrashStore] skip \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return items.sorted {
            let a = (Mirror(reflecting: $0).children.first { $0.label == "createdAt" }?.value as? Date)
                    ?? ($0 as AnyObject).value(forKey: "createdAt") as? Date
                    ?? .distantPast
            let b = (Mirror(reflecting: $1).children.first { $0.label == "createdAt" }?.value as? Date)
                    ?? ($1 as AnyObject).value(forKey: "createdAt") as? Date
                    ?? .distantPast
            return a > b
        }
    }

    static func loadRange(from: Date? = nil, to: Date? = nil) throws -> [ExceptionModel] {
        let all = try loadAll()
        return all.filter { info in
            let d = (info as AnyObject).value(forKey: "createdAt") as? Date ?? .distantPast
            if let from = from, d < from { return false }
            if let to = to, d > to { return false }
            return true
        }
    }

    static func loadLatest() throws -> ExceptionModel? {
        try loadAll().first
    }

    static func loadLatest(limit: Int) throws -> [ExceptionModel] {
        Array(try loadAll().prefix(limit))
    }

    static func loadByFilename(_ filename: String) throws -> ExceptionModel? {
        let dir = try crashLogsDirectory()
        let url = dir.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: url)
        return try decoder.decode(ExceptionModel.self, from: data)
    }
}
