import Foundation


final class FileUtils {
    private nonisolated(unsafe) static let fileManager = FileManager.default
    
    private static let diskKey = DispatchSpecificKey<UInt8>()
    private static let didInstallSpecific: Void = {
        Queues.diskRoot.setSpecific(key: diskKey, value: 1)
    }()
    
    private static var breadcrumbsURL: URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        return documentsDirectory.appendingPathComponent("\(BreadcrumbsConstants.fileName).json")
    }
    
    static func saveBreadcrumb(_ breadcrumb: BreadcrumbEntity) {
        safeSync {
            var existing: [BreadcrumbEntity] = getAllBreadcrumbsFile() ?? []
            existing.append(breadcrumb)
            
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .custom { date, encoder in
                    var c = encoder.singleValueContainer()
                    try c.encode(DateUtils.utcCustomFormatString(from: date))
                }
                let data = try encoder.encode(existing)
                try data.write(to: breadcrumbsURL, options: .atomic)
                AppAmbitLogger.log(message: "Breadcrumb saved successfully")
            } catch {
                AppAmbitLogger.log(message: "Error saving breadcrumb: \(error.localizedDescription)")
            }
        }
    }
    
    static func getAllBreadcrumbsFile() -> [BreadcrumbEntity]? {
        safeSync {
            guard fileManager.fileExists(atPath: breadcrumbsURL.path) else {
                return []
            }
            do {
                let data = try Data(contentsOf: breadcrumbsURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateStr = try container.decode(String.self)
                    guard let date = DateUtils.utcCustomFormatDate(from: dateStr) else {
                        throw DecodingError.dataCorruptedError(in: container,
                            debugDescription: "Invalid date format: \(dateStr)")
                    }
                    return date
                }
                return try decoder.decode([BreadcrumbEntity].self, from: data)
            } catch {
                AppAmbitLogger.log(message: "Error loading breadcrumbs: \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    static func removeLastDestroyBreadcrumb() {
        safeSync {
            guard fileManager.fileExists(atPath: breadcrumbsURL.path) else { return }

            do {
                var breadcrumbs = getAllBreadcrumbsFile() ?? []

                if let last = breadcrumbs.last, last.name == BreadcrumbsConstants.appDestroy {
                    breadcrumbs.removeLast()

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .custom { date, encoder in
                        var c = encoder.singleValueContainer()
                        try c.encode(DateUtils.utcCustomFormatString(from: date))
                    }
                    let data = try encoder.encode(breadcrumbs)
                    try data.write(to: breadcrumbsURL, options: .atomic)
                    
                    AppAmbitLogger.log(message: "Last appDestroy breadcrumb removed")
                }
            } catch {
                AppAmbitLogger.log(message: "Error removing destroy breadcrumb: \(error.localizedDescription)")
            }
        }
    }

    static func deleteBreadcrumbsFile() {
        safeSync {
            do {
                if fileManager.fileExists(atPath: breadcrumbsURL.path) {
                    try fileManager.removeItem(at: breadcrumbsURL)
                    AppAmbitLogger.log(message: "All breadcrumbs deleted")
                }
            } catch {
                AppAmbitLogger.log(message: "Error deleting breadcrumbs: \(error.localizedDescription)")
            }
        }
    }
    
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
