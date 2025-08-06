import Foundation

final class FileUtils {
    
    private nonisolated(unsafe) static let fileManager = FileManager.default
    private static let fileQueue = DispatchQueue(label: "com.appambit.fileutils.queue")
    
    private static func fileName<T>(for type: T.Type) -> String {
        return "\(String(describing: type)).json"
    }
    
    private static func fileURL<T>(for type: T.Type) -> URL {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        return documentsDirectory.appendingPathComponent(fileName(for: type))
    }
    
    static func save<T: Encodable>(_ object: T) {
        fileQueue.sync {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .custom { date, encoder in
                    var container = encoder.singleValueContainer()
                    let isoString = DateUtils.utcIsoFormatString(from: date)
                    try container.encode(isoString)
                }
                
                let data = try encoder.encode(object)
                let url = fileURL(for: T.self)
                
                try data.write(to: url, options: .atomic)
                debugPrint("Saved \(T.self) to \(url.path)")
            } catch {
                debugPrint("Error saving \(T.self): \(error.localizedDescription)")
            }
        }
    }
    
    static func getSavedSingleObject<T: Decodable>(_ type: T.Type) -> T? {
        return fileQueue.sync {
            let url = fileURL(for: T.self)
            do {
                guard fileManager.fileExists(atPath: url.path) else {
                    debugPrint("File for \(T.self) does not exist at \(url.path)")
                    return nil
                }
                let data = try Data(contentsOf: url)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    guard let date = DateUtils.utcIsoFormatDate(from: dateString) else {
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Invalid date format: \(dateString)"
                        )
                    }
                    return date
                }
                
                let object = try decoder.decode(T.self, from: data)
                
                try fileManager.removeItem(at: url)
                debugPrint("Loaded and deleted \(T.self) from \(url.path)")
                return object
            } catch {
                debugPrint("Error loading \(T.self): \(error.localizedDescription)")
                return nil
            }
        }
    }
}
