import Foundation

final class ServiceContainer {
    let apiService: ApiService
    let appInfoService: AppInfoService
    let storageService: StorageService
    let reachabilityService: ReachabilityService

    private nonisolated(unsafe) static let _instance: ServiceContainer = {
        let dataStore: DataStore
        let storageService: StorageService
        let reachabilityService: ReachabilityService

        do {
            dataStore = try DataStore()
            storageService = try StorableService(ds: dataStore)

            guard let reachability = ReachabilityService() else {
                throw NSError(
                    domain: "ServiceContainer",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to initialize ReachabilityService"]
                )
            }

            reachabilityService = reachability

        } catch {
            debugPrint("Error initializing ServiceContainer: \(error.localizedDescription)")
            fatalError("Failed to initialize ServiceContainer")
        }

        return ServiceContainer(
            apiService: AppAmbitApiService(storageService: storageService),
            appInfoService: AppAmbitInfoService(),
            storageService: storageService,
            reachabilityService: reachabilityService
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

    private init(
        apiService: ApiService,
        appInfoService: AppInfoService,
        storageService: StorageService,
        reachabilityService: ReachabilityService
    ) {
        self.apiService = apiService
        self.appInfoService = appInfoService
        self.storageService = storageService
        self.reachabilityService = reachabilityService
    }
}
