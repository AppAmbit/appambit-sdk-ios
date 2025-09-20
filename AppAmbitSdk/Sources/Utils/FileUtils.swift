import Foundation


final class FileUtils {
    private nonisolated(unsafe) static let fileManager = FileManager.default
    
    private static let diskKey = DispatchSpecificKey<UInt8>()
    private static let didInstallSpecific: Void = {
        Queues.diskRoot.setSpecific(key: diskKey, value: 1)
    }()
    private static func safeSync<R>(_ work: () throws -> R) rethrows -> R {
        _ = didInstallSpecific
        if DispatchQueue.getSpecific(key: diskKey) != nil {
            return try work()
        } else {
            return try Queues.diskRoot.sync(execute: work)
        }
    }
    
    private static func fileName<T>(for type: T.Type) -> String {
        "\(String(describing: type)).json"
    }
    
    private static func fileURL<T>(for type: T.Type) -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        return documentsDirectory.appendingPathComponent(fileName(for: type))
    }
    
    static func save<T: Encodable>(_ object: T) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var c = encoder.singleValueContainer()
                try c.encode(DateUtils.utcIsoFormatString(from: date))
            }
            let data = try encoder.encode(object)
            let url  = fileURL(for: T.self)
            
            try safeSync {
                try data.write(to: url, options: .atomic)
            }
            AppAmbitLogger.log(message: "Saved \(T.self)")
        } catch {
            AppAmbitLogger.log(message: "Error saving \(T.self): \(error.localizedDescription)")
        }
    }
    
    static func getSavedSingleObject<T: Decodable>(_ type: T.Type) -> T? {
        do {
            let url = fileURL(for: T.self)

            let dataOrNil: Data? = try safeSync {
                guard fileManager.fileExists(atPath: url.path) else {
                    AppAmbitLogger.log(message: "File for \(T.self) does not exist")
                    return nil
                }
                return try Data(contentsOf: url)
            }
            guard let data = dataOrNil else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let c = try decoder.singleValueContainer()
                let s = try c.decode(String.self)
                guard let d = DateUtils.utcIsoFormatDate(from: s) else {
                    throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date format: \(s)")
                }
                return d
            }

            let object = try decoder.decode(T.self, from: data)
            AppAmbitLogger.log(message: "Loaded \(T.self)")
            return object
        } catch {
            AppAmbitLogger.log(message: "Error loading \(T.self): \(error.localizedDescription)")
            return nil
        }
    }

    static func deleteSingleObject<T>(_ type: T.Type) {
        do {
            let url = fileURL(for: T.self)
            try safeSync {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    AppAmbitLogger.log(message: "Deleted \(T.self)")
                } else {
                    AppAmbitLogger.log(message: "No file to delete for \(T.self)")
                }
            }
        } catch {
            AppAmbitLogger.log(message: "Error deleting \(T.self): \(error.localizedDescription)")
        }
    }
}
