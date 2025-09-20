import Foundation

final class ConsumerService: @unchecked Sendable {
    static let shared = ConsumerService(
        appInfoService: ServiceContainer.shared.appInfoService,
        storageService: ServiceContainer.shared.storageService
    )

    private let appInfoService: AppInfoService
    private let storageService: StorageService

    private init(appInfoService: AppInfoService, storageService: StorageService) {
        self.appInfoService = appInfoService
        self.storageService = storageService
    }

    private func buildRegisterEndpoint() -> RegisterEndpoint {
        let os          = appInfoService.os ?? "iOS"
        let deviceModel = appInfoService.deviceModel ?? "Unknown Model"
        let country     = appInfoService.country ?? Locale.current.regionCode ?? "Unknown country"
        let language    = appInfoService.language ?? Locale.current.languageCode ?? "Unknown language"

        var appId: String?
        var deviceId: String?, userId: String?, userEmail: String?

        do {
            deviceId  = try storageService.getDeviceId()
            userId    = try storageService.getUserId()
            userEmail = try storageService.getUserEmail()
            appId     = try storageService.getAppId()

            if deviceId?.isEmpty ?? true {
                let new = UUID().uuidString
                try storageService.putDeviceId(new)
                deviceId = new
            }
            if userId?.isEmpty ?? true {
                let new = UUID().uuidString
                try storageService.putUserId(new)
                userId = new
            }
        } catch {
            debugPrint("ConsumerService buildRegisterEndpoint error: \(error)")
        }

        return RegisterEndpoint(consumer: Consumer(
            appKey: appId ?? "",
            deviceId: deviceId ?? "",
            deviceModel: deviceModel,
            userId: userId ?? "",
            userEmail: userEmail,
            os: os,
            country: country,
            language: language
        ))
    }

    func createConsumer(
        completion: @escaping @Sendable (ApiErrorType) -> Void
    ) {
        Queues.state.async { [weak self] in
            guard let self = self else { return }
            let endpoint = self.buildRegisterEndpoint()

            ServiceContainer.shared.apiService.executeRequest(
                endpoint,
                responseType: TokenResponse.self
            ) { result in
                if let token = result.data?.token {
                    ServiceContainer.shared.apiService.setToken(token)
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
        if newKey.isEmpty { return }

        do {
            let storedKey = try storageService.getAppId()
            if storedKey == newKey { return }
            try storageService.putConsumerId("")
            try storageService.putAppId(newKey)
        } catch {
            debugPrint("updateAppKeyIfNeeded error: \(error)")
        }
    }
}
