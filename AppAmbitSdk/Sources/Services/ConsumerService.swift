import Foundation

/// Servicio encargado de gestionar el registro y la actualización del consumidor (usuario/dispositivo) en el backend.
/// Maneja la generación de IDs locales y la sincronización con los endpoints de registro.
public final class ConsumerService: @unchecked Sendable {
    public static let shared = ConsumerService(
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
        let appVersion = appInfoService.appVersion ?? "Unknown"

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
            debugPrint("Error en ConsumerService buildRegisterEndpoint: \(error)")
        }

        return RegisterEndpoint(consumer: Consumer(
            appKey: appId ?? "",
            appVersion: appVersion,
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
    
    /// Actualiza el estado del consumidor en el backend (token de push y estado de habilitación).
    public func updateConsumer(deviceToken: String?, pushEnabled: Bool?) {
        updateConsumer(deviceToken: deviceToken, pushEnabled: pushEnabled, completion: nil)
    }
    
    /// Actualiza el estado del consumidor en el backend con un callback opcional para el resultado.
    public func updateConsumer(
        deviceToken: String?,
        pushEnabled: Bool?,
        completion: (@Sendable (Bool) -> Void)?
    ) {
        do {
            if let enabled = pushEnabled {
                try storageService.putPushEnabled(enabled)
                if !enabled {
                    try storageService.putDeviceToken("")
                }
            }
            if let token = deviceToken, pushEnabled != false {
                try storageService.putDeviceToken(token)
            }
        } catch {
            debugPrint("Error saving push data to storage: \(error)")
            DispatchQueue.main.async { completion?(false) }
            return
        }
        
        guard let consumerId = try? storageService.getConsumerId(),
              !consumerId.isEmpty else {
            debugPrint("No se puede actualizar el consumidor, falta el consumerId.")
            DispatchQueue.main.async { completion?(false) }
            return
        }
        
        let storedToken = (try? storageService.getDeviceToken()) ?? ""
        let storedPushEnabled = (try? storageService.getPushEnabled()) ?? true
        let hasToken = !storedToken.isEmpty
        let hasExplicitPushEnabled = (pushEnabled != nil)
        
        if !hasToken && !hasExplicitPushEnabled {
            debugPrint("No hay datos de push para sincronizar. Omitiendo actualización.")
            DispatchQueue.main.async { completion?(false) }
            return
        }
        
        let request = UpdateConsumer(
            deviceToken: hasToken ? storedToken : nil,
            pushEnabled: storedPushEnabled
        )
        let endpoint = UpdateConsumerEndpoint(consumerId: consumerId, request: request)
        
        Queues.state.async { [weak self] in
            guard let self = self else { return }
            ServiceContainer.shared.apiService.executeRequest(
                endpoint,
                responseType: VoidResponse.self
            ) { result in
                let success = (result.errorType == .none)
                if success {
                    debugPrint("Actualización del consumidor enviada con éxito.")
                } else {
                    debugPrint("Error al enviar la actualización del consumidor: \(result.errorType)")
                }
                DispatchQueue.main.async {
                    completion?(success)
                }
            }
        }
    }
}
