import XCTest
@testable import AppAmbit

final class AnalyticsTests: XCTestCase {
    private var api: StubApiService!
    private var storage: InMemoryStorage!

    override func setUp() {
        super.setUp()
        api = StubApiService()
        storage = InMemoryStorage()
        Analytics.isManualSessionEnabled = false
        Analytics.initialize(apiService: api, storageService: storage)
        SessionManager.initialize(apiService: api, storageService: storage)
    }

    override func tearDown() {
        if SessionManager.isSessionActive {
            waitAsync { done in SessionManager.endSession { _ in done() } }
        }
        api = nil
        storage = nil
        super.tearDown()
    }

    func testStartSession_PersistsStartWithDefaultFlow() {
        api.stub(
            StartSessionEndpoint.self,
            result: ApiResult<SessionResponse>.fail(.unknown, message: "no network")
        )

        waitAsync { done in Analytics.startSession { _ in done() } }

        XCTAssertEqual(storage.sessionData.count, 1)
        let stored = storage.sessionData.first
        XCTAssertEqual(stored?.sessionType, .start)
        XCTAssertTrue((stored?.timestamp.timeIntervalSince1970 ?? 0) > 0)
    }

    func testTrackEvent_WhenApiFails_SavesEventLocally() {
        api.stub(StartSessionEndpoint.self, result: .success(SessionResponse(sessionId: 321)))
        api.stub(EventEndpoint.self, result: ApiResult<EventResponse>.fail(.unknown, message: "offline"))

        waitAsync { done in SessionManager.startSession { _ in done() } }
        waitAsync { done in Analytics.trackEvent(eventTitle: "Signup", data: ["source": "unit-test"]) { _ in done() } }

        XCTAssertEqual(storage.analyticsEvents.count, 1)
        let event = storage.analyticsEvents.first
        XCTAssertEqual(event?.name, "Signup")
        XCTAssertFalse((event?.sessionId ?? "").isEmpty)
    }

    func testTrackEvent_WhenApiOk_DoesNotPersistLocally() {
        api.stub(StartSessionEndpoint.self, result: .success(SessionResponse(sessionId: 999)))
        let response = EventResponse(id: 1, name: "Signup", count: 1, consumerId: 10)
        api.stub(EventEndpoint.self, result: ApiResult<EventResponse>.success(response))

        waitAsync { done in SessionManager.startSession { _ in done() } }
        waitAsync { done in Analytics.trackEvent(eventTitle: "Purchase", data: ["value": "9.99"]) { _ in done() } }

        XCTAssertTrue(storage.analyticsEvents.isEmpty)
    }

    func testManualMode_InternalStart_DoesNotAutoStartSession() {
        Analytics.enableManualSession()
        // Simulate SDK initialization without auto start
        XCTAssertTrue(storage.sessionData.isEmpty)
        XCTAssertFalse(SessionManager.isSessionActive)
    }

    func testManualMode_StartAndEndSessionExplicit() {
        Analytics.enableManualSession()
        api.stub(StartSessionEndpoint.self, result: ApiResult<SessionResponse>.fail(.unknown, message: "offline start"))
        api.stub(EndSessionEndpoint.self, result: ApiResult<EndSessionResponse>.fail(.unknown, message: "offline end"))

        waitAsync { done in SessionManager.startSession { _ in done() } }
        waitAsync { done in SessionManager.endSession { _ in done() } }

        XCTAssertEqual(storage.sessionData.count, 2)
        XCTAssertEqual(storage.sessionData[0].sessionType, .start)
        XCTAssertEqual(storage.sessionData[1].sessionType, .end)
    }

    func testSendBatchSessions_ResolvesSessionIdsAndUpdatesTracking() {
        let baseDate = Date().addingTimeInterval(-7200)
        var localSessions: [SessionBatch] = []
        var events: [EventEntity] = []
        var breadcrumbs: [BreadcrumbEntity] = []

        for idx in 0..<10 {
            let localId = "local-\(idx)"
            let startedAt = baseDate.addingTimeInterval(TimeInterval(idx * 60))
            let endedAt = startedAt.addingTimeInterval(60)
            localSessions.append(SessionBatch(id: localId, sessionId: nil, startedAt: startedAt, endedAt: endedAt))

            for e in 0..<25 {
                events.append(EventEntity(
                    id: "\(localId)-evt-\(e)",
                    sessionId: localId,
                    createdAt: startedAt.addingTimeInterval(TimeInterval(e)),
                    name: "event-\(e)",
                    metadata: [:]
                ))
                breadcrumbs.append(BreadcrumbEntity(
                    id: "\(localId)-bc-\(e)",
                    sessionId: localId,
                    name: "crumb-\(e)",
                    createdAt: startedAt.addingTimeInterval(TimeInterval(e))
                ))
            }
        }

        storage.sessionBatches = localSessions
        storage.analyticsEvents = events
        storage.breadcrumbs = breadcrumbs

        let serverSessions: [SessionBatch] = localSessions.map {
            SessionBatch(id: "", sessionId: "srv-\($0.id)", startedAt: $0.startedAt, endedAt: $0.endedAt)
        }
        api.stub(SessionBatchEndpoint.self, result: ApiResult<[SessionBatch]>.success(serverSessions))

        _ = waitAsyncError { cb in SessionManager.sendBatchSessions(completion: cb) }

        XCTAssertTrue(storage.sessionBatches.isEmpty)
        XCTAssertEqual(storage.analyticsEvents.count, 250)
        XCTAssertEqual(storage.breadcrumbs.count, 250)
        XCTAssertTrue(storage.analyticsEvents.allSatisfy { $0.sessionId.hasPrefix("srv-") })
        XCTAssertTrue(storage.breadcrumbs.allSatisfy { ($0.sessionId ?? "").hasPrefix("srv-") })
    }

    func testSendBatchEvents_WithOldEvents_RemovesEventsFromStorage() {
        let now = Date()
        storage.analyticsEvents = [
            EventEntity(id: "e1", sessionId: "local-1", createdAt: now.addingTimeInterval(-3600), name: "a", metadata: [:]),
            EventEntity(id: "e2", sessionId: "local-1", createdAt: now.addingTimeInterval(-10), name: "b", metadata: [:])
        ]

        api.stub(EventBatchEndpoint.self, result: ApiResult<BatchResponse>.success(BatchResponse(message: "ok")))

        _ = waitAsyncError { cb in Analytics.sendBatchEvents(completion: cb) }

        XCTAssertTrue(storage.analyticsEvents.isEmpty)
        XCTAssertGreaterThan(api.callCount(for: EventBatchEndpoint.self), 0)
    }
}
