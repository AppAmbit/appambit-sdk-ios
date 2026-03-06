import Foundation

final class BreadcrumbManager: @unchecked Sendable {
    private var api: ApiService?
    private var storage: StorageService?
    private var lastBreadcrumb: String?
    private var isSendingBatch = false
    private var waiters: [(@Sendable (Error?) -> Void)] = []
    private var isLoadingBreadcrumbs = false

    private static let batchLock = NSLock()
    private static let batchSendTimeout: TimeInterval = 10

    private static let stateKey = DispatchSpecificKey<UInt8>()
    private static let didInstallSpecific: Void = {
        Queues.state.setSpecific(key: stateKey, value: 1)
    }()

    static let shared = BreadcrumbManager()
    private init() {}

    nonisolated(unsafe) static var streamCrashSessionsOnly: Bool = false

    static func initialize(apiService: ApiService, storageService: StorageService) {
        shared.api = apiService
        shared.storage = storageService
    }

    static func addAsync(name: String) {
        var shouldProceed = true
        safeStateSync {
            if shared.lastBreadcrumb == name { shouldProceed = false } else { shared.lastBreadcrumb = name }
        }
        if !shouldProceed { return }
        let entity = createBreadcrumb(name: name)
        if streamCrashSessionsOnly {
            let data = entity.toData(sessionId: SessionManager.sessionId)
            let saved = FileUtils.getSaveJsonArray(BreadcrumbsConstants.fileName, entry: data)
            AppAmbitLogger.log(message: "[Breadcrumb] Saved to disk (crash-only): '\(name)' — total on disk: \(saved.count)")
        } else {
            sendBreadcumbs(entity: entity)
        }
    }

    static func saveFile(name: String) {
        safeStateSync { shared.lastBreadcrumb = name }
        let breadcrumb = createBreadcrumb(name: name)
        let data = breadcrumb.toData(sessionId: SessionManager.sessionId)
        _ = FileUtils.getSaveJsonArray(BreadcrumbsConstants.fileName, entry: data)
    }

    static func loadBreadcrumbsFromFile(completion: (@Sendable (Error?) -> Void)? = nil) {
        Queues.diskRoot.async {
            guard !shared.isLoadingBreadcrumbs else {
                completion?(AppAmbitLogger.buildError(message: "Already processing breadcrumb files"))
                return
            }
            shared.isLoadingBreadcrumbs = true
            let release: @Sendable () -> Void = {
                Queues.diskRoot.async { shared.isLoadingBreadcrumbs = false }
            }

            guard SessionManager.isSessionActive else {
                AppAmbitLogger.log(message: "There is no active session")
                completion?(AppAmbitLogger.buildError(message: "There is no active session"))
                release()
                return
            }

            let files: [BreadcrumbData] = FileUtils.getSaveJsonArray(BreadcrumbsConstants.fileName, entry: Optional<BreadcrumbData>.none)
            let count = files.count

            guard count > 0 else {
                AppAmbitLogger.log(message: "[Breadcrumb] No breadcrumbs found on disk to load")
                completion?(nil)
                release()
                return
            }

            AppAmbitLogger.log(message: "Processing \(count) breadcrumb file(s)")

            if count == 1, let only = files.first {
                var leftovers: [BreadcrumbData] = []
                do {
                    let e = only.toEntity()
                    try shared.storage?.putBreadcrumb(e)
                } catch {
                    leftovers.append(only)
                }
                FileUtils.updateJsonArray(BreadcrumbsConstants.fileName, updatedList: leftovers)
                completion?(leftovers.isEmpty ? nil : AppAmbitLogger.buildError(message: "Failed to store one breadcrumb"))
                release()
            } else {
                var notSent: [BreadcrumbData] = []
                for item in files {
                    do {
                        let e = item.toEntity()
                        try shared.storage?.putBreadcrumb(e)
                    } catch {
                        notSent.append(item)
                    }
                }
                FileUtils.updateJsonArray(BreadcrumbsConstants.fileName, updatedList: notSent)
                completion?(notSent.isEmpty ? nil : AppAmbitLogger.buildError(message: "Some breadcrumbs failed: \(notSent.count)"))
                release()
            }
        }
    }


    static func clearAllCachedBreadcrumbs(completion: (@Sendable () -> Void)? = nil) {
        FileUtils.updateJsonArray(BreadcrumbsConstants.fileName, updatedList: [BreadcrumbData]())
        AppAmbitLogger.log(message: "Breadcrumbs disk cache cleared (no crash detected)")
        completion?()
    }

    static func sendBatchBreadcrumbs(completion: (@Sendable (Error?) -> Void)? = nil) {
        batchLock.lock()
        if let completion { shared.waiters.append(completion) }
        if shared.isSendingBatch {
            batchLock.unlock()
            return
        }
        shared.isSendingBatch = true
        batchLock.unlock()

        let finish: @Sendable (_ err: Error?) -> Void = { err in
            batchLock.lock()
            shared.isSendingBatch = false
            let callbacks = shared.waiters
            shared.waiters.removeAll()
            batchLock.unlock()
            for cb in callbacks { DispatchQueue.global().async { cb(err) } }
        }

        DispatchQueue.main.async {
            Timer.scheduledTimer(withTimeInterval: batchSendTimeout, repeats: false) { _ in
                batchLock.lock()
                let stillSending = shared.isSendingBatch
                batchLock.unlock()
                if stillSending {
                    finish(AppAmbitLogger.buildError(message: "SendBatchBreadcrumbs timeout"))
                }
            }
        }

        getBreadcrumbsInDb { breadcrumbs, error in
            if let error = error {
                AppAmbitLogger.log(message: "Error getting breadcrumbs: \(error.localizedDescription)")
                finish(error)
                return
            }

            guard let breadcrumbs = breadcrumbs, !breadcrumbs.isEmpty else {
                AppAmbitLogger.log(message: "There are no breadcrumbs to send")
                finish(nil)
                return
            }

            let endpoint = BreadcrumbBatchEndpoint(breadcrumbBatch: breadcrumbs)
            shared.api?.executeRequest(endpoint, responseType: BatchResponse.self) { response in
                if response.errorType != .none {
                    AppAmbitLogger.log(message: "Breadcrumbs were not sent: \(response.message ?? "")")
                    finish(AppAmbitLogger.buildError(message: response.message ?? "Unknown error"))
                    return
                }

                do {
                    try shared.storage?.deleteBreadcrumbList(breadcrumbs)
                    AppAmbitLogger.log(message: "SendBatchBreadcrumbs successfully sent")
                    finish(nil)
                } catch {
                    AppAmbitLogger.log(message: "Failed deleting breadcrumbs: \(error.localizedDescription)")
                    finish(error)
                }
            }
        }
    }

    private static func trySendAsync(
        entity: BreadcrumbEntity,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        guard let api = shared.api else { completion(false); return }
        let ep = BreadcrumbEndpoint(breadcrumbEntity: entity)
        api.executeRequest(ep, responseType: BreadcrumbResponse.self) { response in
            let ok = response.errorType == .none
            DispatchQueue.global(qos: .utility).async { completion(ok) }
        }
    }

    private static func sendBreadcumbs(entity: BreadcrumbEntity) {
        trySendAsync(entity: entity) { sent in
            if !sent {
                try? shared.storage?.putBreadcrumb(entity)
            }
        }
    }

    private static func getBreadcrumbsInDb(
        _ completion: @escaping @Sendable (_ breadcrumbs: [BreadcrumbEntity]?, _ error: Error?) -> Void
    ) {
        Queues.batch.async {
            do {
                let breadcrumbs = try shared.storage?.getOldest100Breadcrumbs()
                completion(breadcrumbs, nil)
            } catch {
                completion(nil, AppAmbitLogger.buildError(message: error.localizedDescription))
            }
        }
    }

    private static func createBreadcrumb(name: String) -> BreadcrumbEntity {
        BreadcrumbEntity(
            id: UUID().uuidString,
            sessionId: SessionManager.sessionId,
            name: name,
            createdAt: DateUtils.utcNow
        )
    }

    private static func safeStateSync<R>(_ work: () -> R) -> R {
        _ = didInstallSpecific
        if DispatchQueue.getSpecific(key: stateKey) != nil {
            return work()
        } else {
            return Queues.state.sync(execute: work)
        }
    }
}
