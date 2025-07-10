import Foundation

final class ServiceContainer {
    let apiService: ApiService
    let appInfoService: AppInfoService
    let storageService: StoragaService

    private nonisolated(unsafe) static let _instance: ServiceContainer = {
        let dataStore: DataStore
        let storageService: StoragaService
        
        do {
            dataStore = try DataStore()
            storageService = try Storable(ds: dataStore)
        } catch {
            debugPrint("Error initializing DataStore: \(error)")
            fatalError("Failed to initialize DataStore")
        }

        return ServiceContainer(
            apiService: AppAmbitApiService(storageService: storageService),
            appInfoService: AppAmbitInfoService(),
            storageService: storageService
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
        storageService: StoragaService
    ) {
        self.apiService = apiService
        self.appInfoService = appInfoService
        self.storageService = storageService
    }
}
