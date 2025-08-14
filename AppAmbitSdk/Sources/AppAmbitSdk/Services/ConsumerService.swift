import Foundation

final class ConsumerService: @unchecked Sendable {
    static let shared = ConsumerService(
        appInfoService: ServiceContainer.shared.appInfoService,
        storageService: ServiceContainer.shared.storageService)

    private let appInfoQueue = DispatchQueue(label: "com.appambit.consumerservice.info")
    private let dbQueue = DispatchQueue(label: "com.appambit.consumerservice.datavase", qos: .utility)
    private let consumerQueue = DispatchQueue(label: "com.appambit.consumerservice.consumer", attributes: .concurrent)
    
    private let appInfoService: AppInfoService
    private let storageService: StorageService

    private init(appInfoService: AppInfoService, storageService: StorageService) {
        self.appInfoService = appInfoService
        self.storageService = storageService
    }

    func buildRegisterEndpoint() -> RegisterEndpoint {
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
            
            appId = try storageService.getAppId()
                        
                        
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
    
    func createConsumer(
        completion: @escaping @Sendable (ApiErrorType) -> Void
    ) {
        consumerQueue.async { [weak self] in
            guard let self = self else { return }

            let endpoint = self.buildRegisterEndpoint()

            ServiceContainer.shared.apiService.executeRequest(
                endpoint,
                responseType: TokenResponse.self
            ) { result in
                if let token = result.data?.token {
                    self.consumerQueue.async(flags: .barrier) {
                        ServiceContainer.shared.apiService.setToken(token)                    
                    }
                }
                
                if let consumerId = result.data?.consumerId {
                    do {
                        try self.storageService.putConsumerId(String(consumerId))
                    } catch {
                        debugPrint("Error saving consumerId: \(error)")
                    }
                }
                let errorType = result.errorType

                DispatchQueue.main.async {
                    completion(errorType)
                }
            }
        }
    }
    
    func updateAppKeyIfNeeded(_ appKey: String?) {
        let newKey = appKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if isBlank(newKey) {
            return
        }

        do {
            let storedKey = try storageService.getAppId()

            if equalsNullable(storedKey, newKey) {
                return
            }

            try storageService.putConsumerId("")
            try storageService.putAppId(newKey)

        } catch {
            debugPrint("updateAppKeyIfNeeded error: \(error)")
        }
    }

    private func equalsNullable(_ a: String?, _ b: String?) -> Bool {
        return a == b
    }

    private func isBlank(_ s: String?) -> Bool {
        guard let s = s else { return true }
        return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

}
