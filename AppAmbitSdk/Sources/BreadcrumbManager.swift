import Foundation

public class BreadcrumbManager: @unchecked Sendable {
    
    private var apiService: ApiService?
    private var storageService: StorageService?
    
    private var pendingBreadcrumbs: [BreadcrumbEntity] = []
    private var isSessionReady: Bool {
        return !(SessionManager.sessionId.isEmpty)
    }
    
    static let shared = BreadcrumbManager()
    private init() {}
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }
    
    func addAsync(name: String) {
        if(apiService == nil || storageService == nil) {
            return;
        }
        
        let entity = createEntity(name: name)
        
        if !isSessionReady {
            pendingBreadcrumbs.append(entity)
            return
        }
        
        trySendAsync(entity: entity) { errorType, response in}
    }
    
    private func createEntity(name: String) -> BreadcrumbEntity {
        let breadcrumb = BreadcrumbEntity(
            id: UUID().uuidString,
            sessionId: SessionManager.sessionId,
            name: name,
            createdAt: DateUtils.utcNow
        )
        return breadcrumb
    }
    
    func trySendAsync(
        entity: BreadcrumbEntity,
        completion: @escaping @Sendable (ApiErrorType, BreadcrumbResponse?) -> Void
    ) {
        Queues.state.async {
            let breadcrumbEndpoint = BreadcrumbEndpoint(breadcrumbEntity: entity)
            
            self.apiService?.executeRequest(breadcrumbEndpoint, responseType: BreadcrumbResponse.self) { response in
                completion(response.errorType, response.data)
            }
        }
    }
    
    func sendPending() {
        
    }
    
    func flushPendingBreadcrumbs() {
        guard isSessionReady else { return }
        
        for i in 0..<pendingBreadcrumbs.count {
            pendingBreadcrumbs[i].sessionId = SessionManager.sessionId
        }
        
        print("Sending \(pendingBreadcrumbs.count) breadcrumbs…")
        
        pendingBreadcrumbs.forEach { entity in
            trySendAsync(entity: entity) { errorType, response in
                if errorType != .none {
                    do {
                        try self.storageService?.putBreadcrumb(entity)
                    } catch {
                        print("Error saving breadcrumb: \(error)")
                    }
                }
            }
        }
        pendingBreadcrumbs.removeAll()
    }
}
