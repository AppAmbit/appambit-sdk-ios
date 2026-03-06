import Foundation


final class FileUtils {
    private nonisolated(unsafe) static let fileManager = FileManager.default
    private static let diskKey = DispatchSpecificKey<UInt8>()
    private static let didInstallSpecific: Void = {
        Queues.diskRoot.setSpecific(key: diskKey, value: 1)
    }()
    private static let baseDir: URL = getBaseDir()
    
    private static func safeSync<R>(_ work: () throws -> R) rethrows -> R {
        _ = didInstallSpecific
        if DispatchQueue.getSpecific(key: diskKey) != nil {
            return try work()
        } else {
            return try Queues.diskRoot.sync(execute: work)
        }
    }
    
    private static func getBaseDir() -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0]
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    static func getFilePath(_ fileName: String) -> String {
        baseDir.appendingPathComponent(fileName).path
    }
    
    static func getFileName(_ type: Any.Type) -> String {
        "\(String(describing: type)).json"
    }
    
    static func saveToFile<T>(_ type: T.Type, json: String) {
        let url = baseDir.appendingPathComponent(getFileName(type))
        safeSync {
            do {
                try Data(json.utf8).write(to: url, options: .atomic)
                AppAmbitLogger.log(message: "Saved \(T.self) to \(url.path)")
            } catch {
                AppAmbitLogger.log(message: "Error saving \(T.self) to file: \(error.localizedDescription)")
            }
        }
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
            let url  = baseDir.appendingPathComponent(getFileName(T.self))
            try safeSync { try data.write(to: url, options: .atomic) }
            AppAmbitLogger.log(message: "Saved \(T.self)")
        } catch {
            AppAmbitLogger.log(message: "Error saving \(T.self): \(error.localizedDescription)")
        }
    }
    
    static func getSavedSingleObject<T: Decodable>(_ type: T.Type) -> T? {
        do {
            let url = baseDir.appendingPathComponent(getFileName(T.self))
            let dataOrNil: Data? = try safeSync {
                guard fileManager.fileExists(atPath: url.path) else { return nil }
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
            return try decoder.decode(T.self, from: data)
        } catch {
            AppAmbitLogger.log(message: "Error loading \(T.self): \(error.localizedDescription)")
            return nil
        }
    }
    
    static func deleteSingleObject<T>(_ type: T.Type) {
        do {
            let url = baseDir.appendingPathComponent(getFileName(T.self))
            try safeSync {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                    AppAmbitLogger.log(message: "Deleted \(T.self)")
                }
            }
        } catch {
            AppAmbitLogger.log(message: "Error deleting \(T.self): \(error.localizedDescription)")
        }
    }
    
    static func getSaveJsonArray<T: Codable & IIdentifiable>(_ fileName: String, entry: T?) -> [T] {
        let prepared = prepareFileSettings(fileName)
        let url = prepared.url
        let encoder = prepared.encoder
        let decoder = prepared.decoder

        do {
            return try safeSync {
                var list: [T] = []
                if fileManager.fileExists(atPath: url.path) {
                    let data = try Data(contentsOf: url)
                    list = (try? decoder.decode([T].self, from: data)) ?? []
                }

                if let entry = entry, !list.contains(where: { $0.id == entry.id }) {
                    list.append(entry)
                    let listSorted = list.sorted { $0.timestamp < $1.timestamp }
                    let out = try encoder.encode(listSorted)
                    try out.write(to: url, options: .atomic)
                }

                return list
            }
        } catch {
            AppAmbitLogger.log(message: "File Exception: \(error.localizedDescription)")
            return []
        }
    }
    
    static func updateJsonArray<T: Codable>(_ fileName: String, updatedList: [T]) {
        do {
            let prepared = prepareFileSettings(fileName)
            let url = prepared.url
            let encoder = prepared.encoder
            
            if updatedList.isEmpty {
                if fileManager.fileExists(atPath: url.path) {
                    try safeSync { try fileManager.removeItem(at: url) }
                }
                return
            }
            
            let out = try encoder.encode(updatedList)
            try safeSync { try out.write(to: url, options: .atomic) }
        } catch {
            AppAmbitLogger.log(message: "Error to save file json")
        }
    }
    
    private static func prepareFileSettings(_ fileName: String) -> (fileName: String, encoder: JSONEncoder, decoder: JSONDecoder, url: URL) {
        var name = fileName
        if !name.lowercased().hasSuffix(".json") { name += ".json" }
        let url = baseDir.appendingPathComponent(name)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(DateUtils.utcIsoFormatString(from: date))
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            guard let d = DateUtils.utcIsoFormatDate(from: s) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date format: \(s)")
            }
            return d
        }
        
        return (name, encoder, decoder, url)
    }
}
