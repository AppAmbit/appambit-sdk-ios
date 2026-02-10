import Foundation
import XCTest
@testable import AppAmbit

final class StubApiService: ApiService {
    private let queue = DispatchQueue(label: "com.appambit.tests.api")
    private var stubbedResults: [String: Any] = [:]
    private var calls: [String: Int] = [:]

    var token: String?

    func executeRequest<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        completion: @Sendable @escaping (ApiResult<T>) -> Void
    ) {
        let key = String(describing: type(of: endpoint))
        queue.sync {
            calls[key, default: 0] += 1
        }

        if let result = stubbedResults[key] as? ApiResult<T> {
            completion(result)
            return
        }

        completion(ApiResult(data: nil, errorType: .none))
    }

    func getNewToken(completion: @escaping @Sendable (ApiErrorType) -> Void) {
        completion(.none)
    }

    func setToken(_ newToken: String) {
        token = newToken
    }

    func stub<T: Decodable>(_ endpointType: Endpoint.Type, result: ApiResult<T>) {
        let key = String(describing: endpointType)
        stubbedResults[key] = result
    }

    func callCount(for endpointType: Endpoint.Type) -> Int {
        queue.sync { calls[String(describing: endpointType), default: 0] }
    }
}

final class InMemoryStorage: StorageService {
    private let queue = DispatchQueue(label: "com.appambit.tests.storage")

    private var deviceId: String?
    private var appId: String?
    private var userId: String?
    private var userEmail: String?
    private var storedSessionId: String?
    private var consumerId: String?

    var analyticsEvents: [EventEntity] = []
    var logEvents: [LogEntity] = []
    var sessionData: [SessionData] = []
    var sessionBatches: [SessionBatch] = []
    var breadcrumbs: [BreadcrumbEntity] = []
    var remoteConfigs: [String: RemoteConfigEntity] = [:]
    var deviceToken: String?
    var pushEnabled: Bool = false

    func putDeviceId(_ deviceId: String) throws { queue.sync { self.deviceId = deviceId } }
    func getDeviceId() throws -> String? { queue.sync { deviceId } }

    func putAppId(_ appId: String) throws { queue.sync { self.appId = appId } }
    func getAppId() throws -> String? { queue.sync { appId } }

    func putUserId(_ userId: String) throws { queue.sync { self.userId = userId } }
    func getUserId() throws -> String? { queue.sync { userId } }

    func putUserEmail(_ email: String) throws { queue.sync { self.userEmail = email } }
    func getUserEmail() throws -> String? { queue.sync { userEmail } }

    func putSessionId(_ sessionId: String) throws { queue.sync { self.storedSessionId = sessionId } }
    func getSessionId() throws -> String? { queue.sync { storedSessionId } }

    func putConsumerId(_ consumerId: String) throws { queue.sync { self.consumerId = consumerId } }
    func getConsumerId() throws -> String? { queue.sync { consumerId } }

    func putDeviceToken(_ deviceToken: String) throws { queue.sync { self.deviceToken = deviceToken } }
    func getDeviceToken() throws -> String? { queue.sync { deviceToken } }

    func putPushEnabled(_ pushEnabled: Bool) throws { queue.sync { self.pushEnabled = pushEnabled } }
    func getPushEnabled() throws -> Bool { queue.sync { pushEnabled } }

    func putLogEvent(_ log: LogEntity) throws {
        queue.sync {
            var copy = log
            copy.createdAt = log.createdAt ?? Date()
            logEvents.append(copy)
        }
    }

    func putLogAnalyticsEvent(_ event: EventEntity) throws {
        queue.sync { analyticsEvents.append(event) }
    }

    func deleteLogList(_ logs: [LogEntity]) throws {
        queue.sync {
            let ids = Set(logs.compactMap { $0.id })
            logEvents.removeAll { item in ids.contains(item.id ?? "") }
        }
    }

    func getOldest100Logs() throws -> [LogEntity] {
        queue.sync {
            logEvents
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
                .prefix(100)
                .map { $0 }
        }
    }

    func getOldest100Events() throws -> [EventEntity] {
        queue.sync {
            analyticsEvents
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(100)
                .map { $0 }
        }
    }

    func deleteEventList(_ events: [EventEntity]) throws {
        queue.sync {
            let ids = Set(events.map { $0.id })
            analyticsEvents.removeAll { ids.contains($0.id) }
        }
    }

    func updateSessionIdsForAllTrackingData(_ sessions: [SessionBatch]) throws {
        queue.sync {
            for mapping in sessions {
                let oldRaw = mapping.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let newRaw = mapping.sessionId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !oldRaw.isEmpty, !newRaw.isEmpty else { continue }

                logEvents = logEvents.map { log in
                    var updated = log
                    if let sid = log.sessionId,
                       sid.compare(oldRaw, options: [.caseInsensitive]) == .orderedSame {
                        updated.sessionId = newRaw
                    }
                    return updated
                }

                analyticsEvents = analyticsEvents.map { evt in
                    if evt.sessionId.compare(oldRaw, options: [.caseInsensitive]) == .orderedSame {
                        return EventEntity(
                            id: evt.id,
                            sessionId: newRaw,
                            createdAt: evt.createdAt,
                            name: evt.name,
                            metadata: evt.metadata
                        )
                    }
                    return evt
                }

                breadcrumbs = breadcrumbs.map { bc in
                    let clone = bc
                    if let sid = bc.sessionId,
                       sid.compare(oldRaw, options: [.caseInsensitive]) == .orderedSame {
                        clone.sessionId = newRaw
                    }
                    return clone
                }

                sessionBatches = sessionBatches.map { batch in
                    if batch.id.compare(oldRaw, options: [.caseInsensitive]) == .orderedSame {
                        return SessionBatch(
                            id: batch.id,
                            sessionId: newRaw,
                            startedAt: batch.startedAt,
                            endedAt: batch.endedAt
                        )
                    }
                    return batch
                }
            }
        }
    }

    func getUnpairedSessionStart() throws -> SessionData? {
        queue.sync { sessionData.first { $0.sessionType == .start } }
    }

    func getUnpairedSessionEnd() throws -> SessionData? {
        queue.sync { sessionData.first { $0.sessionType == .end } }
    }

    func deleteSessionById(_ idValue: String) throws {
        queue.sync {
            sessionData.removeAll { $0.id == idValue }
            sessionBatches.removeAll { $0.id == idValue }
        }
    }

    func deleteSessionList(_ sessions: [SessionBatch]) throws {
        queue.sync {
            let ids = Set(sessions.map { $0.id })
            sessionBatches.removeAll { ids.contains($0.id) }
        }
    }

    func putSessionData(_ session: SessionData) throws -> Void {
        queue.sync { sessionData.append(session) }
    }

    func getOldest100Sessions() throws -> [SessionBatch] {
        queue.sync {
            sessionBatches
                .sorted { (a, b) in
                    let lhs = a.startedAt ?? Date.distantPast
                    let rhs = b.startedAt ?? Date.distantPast
                    return lhs < rhs
                }
                .prefix(100)
                .map { $0 }
        }
    }

    func putBreadcrumb(_ breadcrumb: BreadcrumbEntity) throws -> Void {
        queue.sync { breadcrumbs.append(breadcrumb) }
    }

    func getOldest100Breadcrumbs() throws -> [BreadcrumbEntity] {
        queue.sync {
            breadcrumbs
                .sorted { $0.createdAt < $1.createdAt }
                .prefix(100)
                .map { $0 }
        }
    }

    func deleteBreadcrumbList(_ breadcrumbs: [BreadcrumbEntity]) throws {
        queue.sync {
            let ids = Set(breadcrumbs.map { $0.id })
            self.breadcrumbs.removeAll { ids.contains($0.id) }
        }
    }

    func putConfigs(_ configs: [RemoteConfigEntity]) throws {
        queue.sync {
            for config in configs {
                remoteConfigs[config.key] = config
            }
        }
    }

    func getConfig(key: String) throws -> RemoteConfigEntity? {
        queue.sync { remoteConfigs[key] }
    }
}

struct StubAppInfoService: AppInfoService {
    var appVersion: String? = "1.0.0"
    var build: String? = "1"
    var platform: String? = "iOS"
    var os: String? = "iOS 17"
    var deviceModel: String? = "UnitTestDevice"
    var country: String? = "US"
    var utcOffset: String? = "0"
    var language: String? = "en"
}

extension XCTestCase {
    final class ExpectationBox: @unchecked Sendable {
        let exp: XCTestExpectation
        init(_ description: String) { self.exp = XCTestExpectation(description: description) }
    }

    func waitAsync(
        description: String = "async",
        timeout: TimeInterval = 2,
        _ block: (@escaping @Sendable () -> Void) -> Void
    ) {
        let box = ExpectationBox(description)
        block { box.exp.fulfill() }
        wait(for: [box.exp], timeout: timeout)
    }

    func waitAsyncError(
        description: String = "async",
        timeout: TimeInterval = 2,
        _ block: (@escaping @Sendable (Error?) -> Void) -> Void
    ) -> Error? {
        final class ErrorBox: @unchecked Sendable {
            var value: Error?
            let lock = NSLock()
            func set(_ v: Error?) {
                lock.lock()
                value = v
                lock.unlock()
            }
        }
        let boxErr = ErrorBox()
        let box = ExpectationBox(description)
        block { err in
            boxErr.set(err)
            box.exp.fulfill()
        }
        wait(for: [box.exp], timeout: timeout)
        return boxErr.value
    }
}

final class TestURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var callCounts: [String: Int] = [:]
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        let path = request.url?.path ?? "unknown"
        Self.lock.lock()
        Self.callCounts[path, default: 0] += 1
        Self.lock.unlock()

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestHandler = nil
        callCounts = [:]
    }
}
