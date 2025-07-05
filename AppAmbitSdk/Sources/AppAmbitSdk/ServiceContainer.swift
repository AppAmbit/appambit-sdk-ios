import Foundation

final class ServiceContainer {
    let apiService: ApiService
    let appInfoService: AppInfoService
    
    private nonisolated(unsafe) static let _instance: ServiceContainer = {
        ServiceContainer(
            apiService: DefaultApiService(),
            appInfoService: DefaultAppInfoService()
        )
    }()
    
    private static let accessQueue = DispatchQueue(
        label: "com.appambit.sdk.service.container",
        attributes: .concurrent
    )

    static var shared: ServiceContainer {
        accessQueue.sync(flags: .barrier) {
            _instance
        }
    }
    
    private init(apiService: ApiService, appInfoService: AppInfoService) {
        self.apiService = apiService
        self.appInfoService = appInfoService
    }

}
