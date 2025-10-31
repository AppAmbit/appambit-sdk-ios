import Foundation

final class BreadcrumbManager: @unchecked Sendable {
    public typealias ErrorCompletion = @Sendable (Error?) -> Void
    
    private var apiService: ApiService?
    private var storageService: StorageService?
    
    private var pendingBreadcrumbs: [BreadcrumbEntity] = []
    private var isSessionReady: Bool {
        return !(SessionManager.sessionId.isEmpty)
    }
    private var isSendingBatch = false
    private var waiters: [ErrorCompletion] = []
    private var batchTimeoutTimer: DispatchSourceTimer?
    private static let batchSendTimeoutSeconds: Int = 30
    
    static let shared = BreadcrumbManager()
    private init() {}
    
    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.apiService = apiService
        shared.storageService = storageService
    }
    
    static func saveBreadcrumbFile(breadcrumbName: String) {
        let entity = BreadcrumbEntity(
            id: UUID().uuidString,
            sessionId: SessionManager.sessionId,
            name: breadcrumbName,
            createdAt: DateUtils.utcNow
        )
        FileUtils.saveBreadcrumb(entity)
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
    
    static func sendBatchBreadcrumbs(completion: @escaping ErrorCompletion = { _ in }) {
        let finish: ErrorCompletion = { err in
            Queues.batch.async {
                shared.isSendingBatch = false
                shared.batchTimeoutTimer?.cancel()
                shared.batchTimeoutTimer = nil
                let cbs = shared.waiters
                shared.waiters.removeAll()
                for cb in cbs { DispatchQueue.global(qos: .utility).async { cb(err) } }
            }
        }

        Queues.batch.async {
            shared.waiters.append(completion)
            guard !shared.isSendingBatch else {
                AppAmbitLogger.log(message: "SendBatchBreadcrumbs skipped: already in progress")
                return
            }
            shared.isSendingBatch = true

            let t = DispatchSource.makeTimerSource(queue: Queues.batch)
            t.schedule(deadline: .now() + .seconds(batchSendTimeoutSeconds))
            t.setEventHandler {
                AppAmbitLogger.log(message: "SendBatchBreadcrumbs timeout: releasing gate")
                finish(AppAmbitLogger.buildError(message: "SendBatchBreadcrumbs timeout"))
            }
            shared.batchTimeoutTimer = t
            t.resume()

            getBreadcrumbsInDbAsync { breadcrumbs, error in
                Queues.batch.async {
                    if let error = error {
                        AppAmbitLogger.log(message: "Error getting breadcrumbs: \(error.localizedDescription)")
                        finish(error); return
                    }
                    guard let breadcrumbs = breadcrumbs, !breadcrumbs.isEmpty else {
                        AppAmbitLogger.log(message: "There are no breadcrumbs to send")
                        finish(nil); return
                    }

                    let endpoint = BreadcrumbBatchEndpoint(breadcrumbBatch: breadcrumbs)
                    shared.apiService?.executeRequest(endpoint, responseType: BatchResponse.self) { response in
                        Queues.batch.async {
                            if response.errorType != .none {
                                AppAmbitLogger.log(message: "Breadcrumbs were not sent: \(response.message ?? "")")
                                finish(AppAmbitLogger.buildError(message: response.message ?? "Unknown error"))
                                return
                            }
                            do {
                                try shared.storageService?.deleteBreadcrumbList(breadcrumbs)
                                AppAmbitLogger.log(message: "SendBatchBreadcrumbs successfully sent")
                                finish(nil)
                            } catch {
                                AppAmbitLogger.log(message: "Failed deleting breadcrumbs: \(error.localizedDescription)")
                                finish(error)
                            }
                        }
                    }
                }
            }
        }
    }
    
    static func sendBreadcrumbsToDatabaseIfExist(completion: @escaping ErrorCompletion = { _ in }) {

        guard let breadcrumbs = FileUtils.loadAll(), !breadcrumbs.isEmpty else {
            AppAmbitLogger.log(message: "No file breadcrumbs to send")
            completion(nil)
            return
        }

        AppAmbitLogger.log(message: "Sending \(breadcrumbs.count) file breadcrumbs to DB")

        let errors: [Error] = []
        let group = DispatchGroup()

        for entity in breadcrumbs {
            group.enter()

            if entity.sessionId == nil || entity.sessionId?.isEmpty == true {
                entity.sessionId = SessionManager.sessionId
            }

            storeBreadcrumbInDb(breadcrumbEntity: entity) { err in
                group.leave()
            }
        }

        group.notify(queue: .global()) {
            if errors.isEmpty {
                AppAmbitLogger.log(message: "All file breadcrumbs successfully sent to DB")
                FileUtils.deleteAll()
                completion(nil)
            } else {
                AppAmbitLogger.log(message: "Some file breadcrumbs failed: \(errors.count)")
                completion(errors.first)
            }
        }
    }

    private static func storeBreadcrumbInDb(breadcrumbEntity: BreadcrumbEntity, completion: @escaping ErrorCompletion = { _ in }) {
        Queues.state.async {
            do {
                try shared.storageService?.putBreadcrumb(breadcrumbEntity)
                DispatchQueue.main.async { completion(nil) }
            } catch {
                DispatchQueue.main.async { completion(error) }
            }
        }
    }
    
    private static func getBreadcrumbsInDbAsync(
        _ completion: @escaping @Sendable (_ breadcrumbs: [BreadcrumbEntity]?, _ error: Error?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let breadcrumbs = try shared.storageService?.getOldest100Breadcrumbs()
                completion(breadcrumbs, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
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
                    BreadcrumbManager.storeBreadcrumbInDb(breadcrumbEntity: entity)
                }
            }
        }
        pendingBreadcrumbs.removeAll()
    }
}
