import Foundation

final class ConsumerService: @unchecked Sendable {
    static let shared = ConsumerService(
        appInfoService: ServiceContainer.shared.appInfoService,
        storageService: ServiceContainer.shared.storageService)

    private let appInfoQueue = DispatchQueue(label: "com.appambit.consumerservice.access")
    private let dbQueue = DispatchQueue(label: "com.appambit.database.queue", qos: .utility)
    private let appInfoService: AppInfoService
    private let storageService: StorageService

    private init(appInfoService: AppInfoService, storageService: StorageService) {
        self.appInfoService = appInfoService
        self.storageService = storageService
    }

    func registerConsumer(appKey: String?) -> RegisterEndpoint {
        let info = appInfoQueue.sync {
            (
                os: appInfoService.os ?? "iOS",
                deviceModel: appInfoService.deviceModel ?? "Unknown Model",
                country: appInfoService.country ?? Locale.current.regionCode ?? "Unknown country",
                language: appInfoService.language ?? Locale.current.languageCode ?? "Unknown language"
            )
        }
        
        var appId:String?
        var deviceId:String?, userId:String?, userEmail:String?
        do {
            deviceId = try storageService.getDeviceId()
            userId = try storageService.getUserId()
            userEmail = try storageService.getUserEmail()
            
            if !(appKey?.isEmpty ?? true) {
                appId = appKey
                try storageService.putAppId(appId ?? "")
            }
            
            if appKey?.isEmpty ?? true  {
                if let storageAppKey = try storageService.getAppId() {
                    appId = storageAppKey
                }
            }
                        
            if deviceId?.isEmpty ?? true {
                deviceId = UUID().uuidString
                try storageService.putDeviceId(deviceId!)
            }
                        
            if userId?.isEmpty ?? true {
                userId = UUID().uuidString
                try storageService.putUserId(userId!)
            }
        } catch {
            debugPrint("Error to get data for AppSecrets  ConsumerService: \(error)")
        }
    
        return RegisterEndpoint(consumer: Consumer(
            appKey: appId ?? "",
            deviceId: deviceId ?? "",
            deviceModel: info.deviceModel,
            userId: userId ?? "",
            userEmail: userEmail,
            os: info.os,
            country: info.country,
            language: info.language
        ))
    }
}
