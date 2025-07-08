import Foundation

final class ConsumerService {
    private nonisolated(unsafe) static let _instance: ConsumerService = {
        let appInfoService = ServiceContainer.shared.appInfoService
        return ConsumerService(appInfoService: appInfoService)
    }()

    static var shared: ConsumerService {
        return _instance
    }

    private static let accessQueue = DispatchQueue(label: "com.appambit.consumerservice.access")

    private let appInfoService: AppInfoService

    private init(appInfoService: AppInfoService) {
        self.appInfoService = appInfoService
    }

    func registerConsumer(appKey: String) -> RegisterEndpoint {
        let info = Self.accessQueue.sync {
            let os = appInfoService.os ?? "iOS"
            let deviceModel = appInfoService.deviceModel ?? "Unknown Model"
            let country = appInfoService.country ?? Locale.current.regionCode ?? "Unknown country"
            let language = appInfoService.language ?? Locale.current.languageCode ?? "Unknown language"
            return (os: os, deviceModel: deviceModel, country: country, language: language)
        }

        return RegisterEndpoint(consumer: Consumer(
            appKey: appKey,
            deviceId: UUID().uuidString,
            deviceModel: info.deviceModel,
            userId: UUID().uuidString,
            userEmail: "test@mail.com",
            os: info.os,
            country: info.country,
            language: info.language
        ))
    }
}
