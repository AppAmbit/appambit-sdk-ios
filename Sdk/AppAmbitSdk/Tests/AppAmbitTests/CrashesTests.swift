import Foundation
import XCTest
@testable import AppAmbit

final class CrashesTests: XCTestCase {
    private var api: StubApiService!
    private var storage: InMemoryStorage!

    override func setUp() {
        super.setUp()
        api = StubApiService()
        storage = InMemoryStorage()
        SessionManager.initialize(apiService: api, storageService: storage)
        Analytics.initialize(apiService: api, storageService: storage)
        BreadcrumbManager.initialize(apiService: api, storageService: storage)
        Crashes.initialize(apiService: api, storageService: storage)
        Logging.initialize(apiService: api, storageService: storage)
        api.stub(StartSessionEndpoint.self, result: .success(SessionResponse(sessionId: 123)))

        if SessionManager.isSessionActive {
            waitAsync { done in SessionManager.endSession { _ in done() } }
        }
        purgeLogs()
        waitAsync { done in SessionManager.startSession { _ in done() } }
    }

    override func tearDown() {
        if SessionManager.isSessionActive {
            waitAsync { done in SessionManager.endSession { _ in done() } }
        }
        purgeLogs()
        api = nil
        storage = nil
        super.tearDown()
    }

    func testLogError_PersistsErrorLog() throws {
        api.stub(LogEndpoint.self, result: ApiResult<LogResponse>.fail(.unknown, message: "fail"))
        waitAsync { done in Crashes.logError(message: "boom!") { _ in done() } }

        let logs = try storage.getOldest100Logs()
        XCTAssertEqual(logs.count, 1)
        let log = logs.first
        XCTAssertEqual(log?.type, .error)
        XCTAssertEqual(log?.message, "boom!")
        XCTAssertTrue((log?.createdAt?.timeIntervalSince1970 ?? 0) > 0)
    }

    func testLogError_FromException_PersistsCrashFilePath() throws {
        api.stub(LogEndpoint.self, result: ApiResult<LogResponse>.fail(.unknown, message: "fail"))
        let sample = NSError(domain: "unit", code: 7, userInfo: [NSLocalizedDescriptionKey: "kaboom"])

        waitAsync { done in Crashes.logError(exception: sample) { _ in done() } }

        let logs = try storage.getOldest100Logs()
        XCTAssertEqual(logs.count, 1)
        let log = logs.first
        XCTAssertTrue((log?.message ?? "").contains("kaboom"))
    }

    func testSendBatchLogs_WithApiSuccess_RemovesLogsFromStorage() throws {
        let now = Date()
        let first = LogEntity()
        first.id = "1"
        first.sessionId = SessionManager.sessionId
        first.createdAt = now
        first.type = .error
        first.message = "first"

        let older = LogEntity()
        older.id = "2"
        older.sessionId = SessionManager.sessionId
        older.createdAt = now.addingTimeInterval(-600)
        older.type = .error
        older.message = "older"

        try storage.putLogEvent(first)
        try storage.putLogEvent(older)

        api.stub(LogBatchEndpoint.self, result: ApiResult<BatchResponse>.success(BatchResponse(message: "ok")))

        let err = waitAsyncError { cb in Crashes.sendBatchLogs(completion: cb) }
        XCTAssertNil(err)

        let logs = try storage.getOldest100Logs()
        XCTAssertTrue(logs.isEmpty)
        XCTAssertEqual(api.callCount(for: LogBatchEndpoint.self), 1)
    }

    func testSendBatchLogs_WithBackdatedLogs_StillSendsBatch() throws {
        let past = Date().addingTimeInterval(-3 * 24 * 3600)
        for idx in 0..<2 {
            let log = LogEntity()
            log.id = "back-\(idx)"
            log.sessionId = SessionManager.sessionId
            log.createdAt = past.addingTimeInterval(TimeInterval(idx))
            log.type = .error
            log.message = "old-\(idx)"
            try storage.putLogEvent(log)
        }

        api.stub(LogBatchEndpoint.self, result: ApiResult<BatchResponse>.success(BatchResponse(message: "ok")))

        let err = waitAsyncError { cb in Crashes.sendBatchLogs(completion: cb) }
        XCTAssertNil(err)

        let logs = try storage.getOldest100Logs()
        XCTAssertTrue(logs.isEmpty)
        XCTAssertEqual(api.callCount(for: LogBatchEndpoint.self), 1)
    }

    // MARK: - Helpers

    private func purgeLogs() {
        if let logs = try? storage.getOldest100Logs() {
            try? storage.deleteLogList(logs)
        }
    }
}
