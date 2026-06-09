import XCTest
@testable import AppAmbit

private final class Box<T>: @unchecked Sendable {
    var value: T?
}

private struct EmptyModel: Decodable {}

final class AppAmbitDbTests: XCTestCase {

    private var api: StubApiService!

    override func setUp() {
        super.setUp()
        api = StubApiService()
        AppAmbitDb.initialize(dbService: DbService(apiService: api))
    }

    override func tearDown() {
        api = nil
        super.tearDown()
    }

    // MARK: - execute()

    func testExecute_CallsQueryEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.execute("CREATE TABLE foo (id INTEGER)") { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testExecute_WithParams_PassesParams() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.execute("INSERT INTO foo VALUES (?)", params: [42]) { _, _ in done() }
        }

        XCTAssertNotNil(api.lastEndpoint(for: DbQueryEndpoint.self))
    }

    func testExecute_WhenApiError_CompletesWithError() {
        api.stub(DbQueryEndpoint.self, result: ApiResult<DbApiResponse>.fail(.unknown))

        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.execute("SELECT 1") { _, error in
                box.value = error
                done()
            }
        }

        XCTAssertNotNil(box.value)
    }

    // MARK: - batch()

    func testBatch_CallsBatchEndpoint() {
        stubBatch(results: [makeResultData(rowsWritten: 1)])

        waitAsync { done in
            AppAmbitDb.batch([DbStatement.of("INSERT INTO foo VALUES (1)")]) { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbBatchEndpoint.self), 1)
    }

    // MARK: - batchInTransaction()

    func testBatchInTransaction_WhenResultHasError_CompletesWithError() {
        stubBatch(results: [makeResultData(error: "syntax error")])

        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.batchInTransaction([DbStatement.of("BAD SQL")]) { _, error in
                box.value = error
                done()
            }
        }

        XCTAssertNotNil(box.value)
    }

    // MARK: - from() — SELECT

    func testFrom_Get_ReturnsRowsMappedToMaps() {
        stubQuery(columns: ["id", "name"], rows: [["1", "Alice"]], rowsRead: 1, rowsWritten: 0)

        let box = Box<[[String: Any]]>()
        waitAsync { done in
            AppAmbitDb.from("users").get { rows, _ in box.value = rows; done() }
        }

        XCTAssertEqual(box.value?.count, 1)
        XCTAssertEqual(box.value?.first?["name"] as? String, "Alice")
    }

    func testFrom_Where_BuildsQueryEndpointCall() {
        stubQuery(columns: ["id"], rows: [["5"]], rowsRead: 1, rowsWritten: 0)

        waitAsync { done in
            AppAmbitDb.from("users").`where`("id", value: 5).get { _, _ in done() }
        }

        XCTAssertNotNil(api.lastEndpoint(for: DbQueryEndpoint.self))
    }

    func testFrom_First_ReturnsSingleRow() {
        stubQuery(columns: ["id", "name"], rows: [["1", "Bob"]], rowsRead: 1, rowsWritten: 0)

        let box = Box<[String: Any]>()
        waitAsync { done in
            AppAmbitDb.from("users").first { r, _ in box.value = r; done() }
        }

        XCTAssertEqual(box.value?["name"] as? String, "Bob")
    }

    func testFrom_Count_ReturnsParsedInteger() {
        stubQuery(columns: ["COUNT(*)"], rows: [[42]], rowsRead: 1, rowsWritten: 0)

        let box = Box<Int>()
        box.value = -1
        waitAsync { done in
            AppAmbitDb.from("users").count { n, _ in box.value = n; done() }
        }

        XCTAssertEqual(box.value, 42)
    }

    func testFrom_OrderByDesc_CallsEndpoint() {
        stubQuery(columns: ["id"], rows: [], rowsRead: 0, rowsWritten: 0)

        waitAsync { done in
            AppAmbitDb.from("users").orderByDesc("id").get { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testFrom_LimitAndOffset_CallsEndpoint() {
        stubQuery(columns: ["id"], rows: [], rowsRead: 0, rowsWritten: 0)

        waitAsync { done in
            AppAmbitDb.from("users").limit(10).offset(20).get { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    // MARK: - INSERT / UPDATE / DELETE

    func testFrom_Insert_CallsQueryEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("users").insert(["name": "Alice", "age": 30]) { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testFrom_UpdateWithoutWhere_ReturnsError() {
        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.from("users").update(["name": "Bob"]) { _, error in
                box.value = error
                done()
            }
        }
        XCTAssertNotNil(box.value)
    }

    func testFrom_DeleteWithoutWhere_ReturnsError() {
        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.from("users").delete { _, error in
                box.value = error
                done()
            }
        }
        XCTAssertNotNil(box.value)
    }

    func testFrom_UpdateWithWhere_CallsQueryEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("users").`where`("id", value: 1).update(["name": "Bob"]) { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testFrom_DeleteWithWhere_CallsQueryEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("users").`where`("id", value: 1).delete { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    // MARK: - DbResult

    func testDbResult_ToMaps_KeysByColumn() {
        let result = DbResult(
            columns: ["id", "name"],
            rows: [[1, "Alice"]],
            rowsRead: 1, rowsWritten: 0, error: nil
        )
        let maps = result.toMaps()
        XCTAssertEqual(maps.count, 1)
        XCTAssertEqual(maps[0]["name"] as? String, "Alice")
        XCTAssertEqual(maps[0]["id"] as? Int, 1)
    }

    func testDbResult_ToMaps_OmitsNSNull() {
        let result = DbResult(
            columns: ["id", "name"],
            rows: [[1, NSNull()]],
            rowsRead: 1, rowsWritten: 0, error: nil
        )
        let map = result.toMaps().first ?? [:]
        XCTAssertNil(map["name"])
        XCTAssertNotNil(map["id"])
    }

    func testDbResult_HasError_WhenErrorPresent() {
        let result = DbResult(columns: [], rows: [], rowsRead: 0, rowsWritten: 0, error: "syntax error")
        XCTAssertTrue(result.hasError)
        XCTAssertFalse(result.succeeded)
    }

    func testDbResult_MapTo_DecodesDecodableModel() {
        struct User: Decodable { let id: Int; let name: String }
        let result = DbResult(
            columns: ["id", "name"],
            rows: [[42, "Carol"]],
            rowsRead: 1, rowsWritten: 0, error: nil
        )
        let users = result.mapTo(User.self)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users[0].id, 42)
        XCTAssertEqual(users[0].name, "Carol")
    }

    // MARK: - DbStatement

    func testDbStatement_OfNoParams_HasNilParams() {
        let stmt = DbStatement.of("SELECT 1")
        XCTAssertEqual(stmt.sql, "SELECT 1")
        XCTAssertNil(stmt.params)
    }

    func testDbStatement_OfWithParams_HasParams() {
        let stmt = DbStatement.of("SELECT ?", params: [99])
        XCTAssertEqual(stmt.params?.count, 1)
    }

    // MARK: - SQL Builder (M-5)

    func testBuildSQL_SelectAll_ProducesStarFromTable() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertEqual(sql, #"SELECT * FROM "users""#)
    }

    func testBuildSQL_SelectColumns_ListsQuotedColumns() {
        let builder = DbQueryBuilder(table: "tasks", dbService: nil)
        _ = builder.select(["id", "title"])
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains(#""id", "title""#))
    }

    func testBuildSQL_WhereCondition_AppendsWhereClause() {
        let builder = DbQueryBuilder(table: "tasks", dbService: nil)
        _ = builder.`where`("status", value: "open")
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains(#"WHERE "status" = ?"#))
    }

    func testBuildSQL_OrderByAsc_NoDescKeyword() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        _ = builder.orderBy("created_at")
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains(#"ORDER BY "created_at""#))
        XCTAssertFalse(sql.contains("DESC"))
    }

    func testBuildSQL_OrderByDesc_ContainsDescKeyword() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        _ = builder.orderByDesc("created_at")
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains(#"ORDER BY "created_at" DESC"#))
    }

    func testBuildSQL_LimitAndOffset_AppendedCorrectly() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        _ = builder.limit(10).offset(20)
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains("LIMIT 10"))
        XCTAssertTrue(sql.contains("OFFSET 20"))
    }

    func testBuildSQL_OverrideLimit_TakesPrecedenceOverSet() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        _ = builder.limit(50)
        let sql = builder.buildSelectSQL(overrideLimit: 1)
        XCTAssertTrue(sql.contains("LIMIT 1"))
        XCTAssertFalse(sql.contains("LIMIT 50"))
    }

    func testBuildSQL_WhereIn_ProducesInClause() {
        let builder = DbQueryBuilder(table: "items", dbService: nil)
        _ = builder.whereIn("id", values: [1, 2, 3])
        let sql = builder.buildSelectSQL(overrideLimit: -1)
        XCTAssertTrue(sql.contains(#"WHERE "id" IN (?, ?, ?)"#))
    }

    func testBuildSQL_InvalidOperator_DeferredErrorNotInSQL() {
        let builder = DbQueryBuilder(table: "users", dbService: nil)
        _ = builder.`where`("age", op: "DROP TABLE--", value: 0)
        let box = Box<Error?>()
        waitAsync { done in
            builder.fetchResult(overrideLimit: -1) { _, error in box.value = error; done() }
        }
        XCTAssertNotNil(box.value)
    }

    // MARK: - TypedDbQueryBuilder

    func testTypedBuilder_Get_DecodesModel() {
        struct Task: Decodable { let id: Int; let title: String }
        stubQuery(columns: ["id", "title"], rows: [[1, "Write tests"]], rowsRead: 1, rowsWritten: 0)

        let box = Box<[Task]>()
        waitAsync { done in
            AppAmbitDb.from("tasks", as: Task.self).get { result, _ in box.value = result; done() }
        }

        XCTAssertEqual(box.value?.count, 1)
        XCTAssertEqual(box.value?.first?.title, "Write tests")
    }

    func testTypedBuilder_First_DecodesFirstRow() {
        struct Task: Decodable { let id: Int; let title: String }
        stubQuery(columns: ["id", "title"], rows: [[7, "Deploy"]], rowsRead: 1, rowsWritten: 0)

        let box = Box<Task>()
        waitAsync { done in
            AppAmbitDb.from("tasks", as: Task.self).first { result, _ in box.value = result; done() }
        }

        XCTAssertEqual(box.value?.id, 7)
        XCTAssertEqual(box.value?.title, "Deploy")
    }

    func testTypedBuilder_Count_ReturnsParsedInteger() {
        stubQuery(columns: ["COUNT(*)"], rows: [[3]], rowsRead: 1, rowsWritten: 0)

        let box = Box<Int>()
        box.value = -1
        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self).count { n, _ in box.value = n; done() }
        }

        XCTAssertEqual(box.value, 3)
    }

    func testTypedBuilder_Insert_CallsEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self)
                .insert(["title": "New Task", "done": false]) { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testTypedBuilder_UpdateWithWhere_CallsEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self)
                .`where`("id", value: 1)
                .update(["title": "Updated"]) { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testTypedBuilder_UpdateWithoutWhere_ReturnsError() {
        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self)
                .update(["title": "Oops"]) { _, error in box.value = error; done() }
        }

        XCTAssertNotNil(box.value)
    }

    func testTypedBuilder_DeleteWithWhere_CallsEndpoint() {
        stubQuery(columns: [], rows: [], rowsRead: 0, rowsWritten: 1)

        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self)
                .`where`("id", value: 5)
                .delete { _, _ in done() }
        }

        XCTAssertEqual(api.callCount(for: DbQueryEndpoint.self), 1)
    }

    func testTypedBuilder_DeleteWithoutWhere_ReturnsError() {
        let box = Box<Error>()
        waitAsync { done in
            AppAmbitDb.from("tasks", as: EmptyModel.self)
                .delete { _, error in box.value = error; done() }
        }

        XCTAssertNotNil(box.value)
    }

    // MARK: - Helpers

    private func stubQuery(
        columns: [String],
        rows: [[Any]],
        rowsRead: Int,
        rowsWritten: Int,
        error: String? = nil
    ) {
        let dbValues: [[DbValue]] = rows.map { row in
            row.map { val -> DbValue in
                if let s = val as? String { return .string(s) }
                if let i = val as? Int    { return .int(i) }
                return .string("\(val)")
            }
        }
        let resultData = DbApiResultData(
            columns: columns,
            rows: dbValues,
            rowsRead: rowsRead,
            rowsWritten: rowsWritten,
            error: error
        )
        api.stub(DbQueryEndpoint.self, result: ApiResult<DbApiResponse>.success(
            DbApiResponse(results: [resultData], requestId: nil)
        ))
    }

    private func stubBatch(results: [DbApiResultData]) {
        api.stub(DbBatchEndpoint.self, result: ApiResult<DbApiResponse>.success(
            DbApiResponse(results: results, requestId: nil)
        ))
    }

    private func makeResultData(rowsRead: Int = 0, rowsWritten: Int = 0, error: String? = nil) -> DbApiResultData {
        DbApiResultData(columns: nil, rows: nil, rowsRead: rowsRead, rowsWritten: rowsWritten, error: error)
    }
}
