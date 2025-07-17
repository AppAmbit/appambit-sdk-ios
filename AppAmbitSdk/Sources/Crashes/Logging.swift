import Foundation

final class Logging: Sendable {
    
    private nonisolated(unsafe) static let apiService: ApiService = ServiceContainer.shared.apiService
    private nonisolated(unsafe) static let storable: StorageService = ServiceContainer.shared.storageService
    private static let queue = DispatchQueue(label: "com.appambit.logging.queue", qos: .utility)
    private static let tag = "Logging"
    
    static func logEvent(
        context: Any?, // En iOS no se usa Context, así que podría ser opcional o nil
        message: String?,
        logType: LogType,
        exception: NSException?, // en Swift no hay Exception, uso NSException para ejemplo
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int,
        createdAt: Date?
    ) {
        //let exceptionInfo = exception != nil ? ExceptionInfo.from(exception: exception!) : nil
        logEvent(
            context: context,
            message: message,
            logType: logType,
            //exceptionInfo: exceptionInfo,
            properties: properties,
            classFqn: classFqn,
            fileName: fileName,
            lineNumber: lineNumber,
            createdAt: createdAt
        )
    }
    
    static func logEvent(
        context: Any?,
        message: String?,
        logType: LogType,
        //exceptionInfo: ExceptionInfo?,
        properties: [String: String]?,
        classFqn: String?,
        fileName: String?,
        lineNumber: Int,
        createdAt: Date?
    ) {
        
     
        
        let file = MultipartFile(fileName: "example.txt", mimeType: "text/plain", data: Data("Contenido del archivo".utf8))

        // Obtener info versión app iOS
        let appVersion: String = {
            if let info = Bundle.main.infoDictionary {
                let version = info["CFBundleShortVersionString"] as? String ?? "Unknown"
                let build = info["CFBundleVersion"] as? String ?? "Unknown"
                return "\(version) (\(build))"
            }
            return "Unknown"
        }()
        
        let log = Log()
        log.appVersion = appVersion
        log.classFQN = AppConstants.unknownClass
        log.fileName = AppConstants.unknownFileName
        log.lineNumber = 0
        log.message = message ?? ""
        log.stackTrace = AppConstants.noStackTraceAvailable
        log.context = properties ?? [:]
        log.type = logType
        log.file = (logType == .crash) ? file : nil
        
        sendOrSaveLogEventAsync(log)
    }
    
    private static func sendOrSaveLogEventAsync(_ log: Log) {
        queue.async {
            let apiService = ServiceContainer.shared.apiService
            let logEndpoint = LogEndpoint(log: log)
            
            // Creamos una copia inmutable para el closure Sendable
            let logCopy = log
            
            apiService.executeRequest(logEndpoint, responseType: LogResponse.self) { result in
                
                if result.errorType != .none {
                    debugPrint("\(tag): Save on datbase Log: \(result.message ?? "")")
                    return
                }
                
                debugPrint("\(tag): Log send")
            }
        }
    }

    private static func storeLogInDb(log: LogEntity) {
        do {
            try storable.putLogEvent(log)
            debugPrint("\(tag): Log event stored in database")
        } catch {
            debugPrint("\(tag): Failed to store log event: \(error.localizedDescription)")
        }
    }

    private static func storeLogInDb(_ log: LogEntity, storable: StorageService) {
        queue.async {
            do {
                try storable.putLogEvent(log)
                print("\(tag): Log event stored in database")
            } catch {
                print("\(tag): Failed to store log event: \(error.localizedDescription)")
            }
        }
    }

}
