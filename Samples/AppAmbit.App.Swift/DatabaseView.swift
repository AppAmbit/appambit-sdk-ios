import SwiftUI
import AppAmbit

// MARK: - Model

private struct TaskModel: Decodable {
    let id: Int?
    let title: String?
    let isCompleted: Int?
    let priority: String?
    let dueDate: String?

    enum CodingKeys: String, CodingKey {
        case id, title, priority
        case isCompleted = "is_completed"
        case dueDate = "due_date"
    }
}

// MARK: - View

struct DatabaseView: View {
    @State private var sql = "SELECT * FROM tasks LIMIT 10"
    @State private var resultColumns: [String] = []
    @State private var resultRows: [[Any]] = []
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                resultSection
                rawSQLSection
                schemaSection
                batchSection
                fluentSelectSection
                fluentWriteSection
                typedModelSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Database")
        }
    }

    // MARK: - Sections

    private var resultSection: some View {
        Section("Result") {
            if isLoading {
                ProgressView("Running…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            if let err = errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(err).font(.footnote).foregroundColor(.red)
                }
            }
            if let msg = statusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.secondary)
                    Text(msg).font(.footnote).foregroundColor(.secondary)
                }
            }
            if !resultColumns.isEmpty {
                queryTable(columns: resultColumns, rows: resultRows)
            }
            if !isLoading && errorMessage == nil && statusMessage == nil {
                Text("Tap an action to run a query.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var rawSQLSection: some View {
        Section("Raw SQL") {
            TextField("SQL", text: $sql, axis: .vertical)
                .lineLimit(2...5)
                .font(.system(.caption, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("execute(sql)") { executeSQL() }
            Button("execute(sql, params) — is_completed=0 LIMIT 10") { executeParams() }
            Button("Preset: SELECT sqlite_master tables") {
                let q = "SELECT name FROM sqlite_master WHERE type = 'table'"
                sql = q; executeSQLString(q)
            }
            Button("Preset: SELECT WHERE priority = 'high'") {
                let q = "SELECT * FROM tasks WHERE priority = 'high'"
                sql = q; executeSQLString(q)
            }
        }
    }

    private var schemaSection: some View {
        Section("Schema") {
            Button("CREATE TABLE tasks") { createTable() }
            Button("DROP TABLE tasks") { dropTable() }
        }
    }

    private var batchSection: some View {
        Section("Batch") {
            Button("batch() — 2 inserts + count") { demoBatch() }
            Button("batchInTransaction() — 2 inserts") { demoBatchInTransaction() }
        }
    }

    private var fluentSelectSection: some View {
        Section("Fluent Builder — SELECT") {
            Button("select+where+orderByDesc+limit") { demoFluentSelect() }
            Button("where(is_completed, 0)") { demoWhereEquality() }
            Button("whereIn(priority, [high, medium])") { demoWhereIn() }
            Button("limit(5).offset(0)") { demoOffset() }
            Button("first() — next pending task") { demoFirst() }
            Button("count() — pending tasks") { demoCount() }
        }
    }

    private var fluentWriteSection: some View {
        Section("Fluent Builder — WRITE") {
            Button("insert() — single row (medium priority)") { demoInsert() }
            Button("insert() — high priority task") { demoInsertHigh() }
            Button("insert() — raw SQL execute") { demoInsertRawSQL() }
            Button("insert many — seed 5 rows (batch)") { demoInsertMany() }
            Button("update() — mark as completed") { demoUpdate() }
            Button("delete() — remove completed") { demoDelete() }
        }
    }

    private var typedModelSection: some View {
        Section("Typed Model") {
            Button("from(\"tasks\", as: TaskModel.self)") { demoTypedModel() }
        }
    }

    // MARK: - Table

    @ViewBuilder
    private func queryTable(columns: [String], rows: [[Any]]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(rows.count) row\(rows.count == 1 ? "" : "s") — \(columns.count) col\(columns.count == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(columns.indices, id: \.self) { ci in
                            Text(columns[ci])
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(width: 110, alignment: .leading)
                            if ci < columns.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 1)
                                    .padding(.vertical, 3)
                            }
                        }
                    }
                    .background(Color(.systemGray))

                    if rows.isEmpty {
                        Text("(no rows)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                    } else {
                        ForEach(rows.indices, id: \.self) { ri in
                            HStack(spacing: 0) {
                                ForEach(columns.indices, id: \.self) { ci in
                                    let val: Any = ci < rows[ri].count ? rows[ri][ci] : NSNull()
                                    let isNull = val is NSNull
                                    Text(verbatim: isNull ? "null" : String(describing: val))
                                        .font(.system(.caption, design: .monospaced))
                                        .italic(isNull)
                                        .foregroundColor(isNull ? .secondary : .primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(width: 110, alignment: .leading)
                                    if ci < columns.count - 1 {
                                        Rectangle().fill(Color(.systemGray4)).frame(width: 1)
                                    }
                                }
                            }
                            .background(ri % 2 == 0 ? Color(.systemGray6) : Color(.systemBackground))
                            if ri < rows.count - 1 {
                                Rectangle().fill(Color(.systemGray5)).frame(height: 0.5)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 0.5))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Raw SQL actions

    private func executeSQL() {
        executeSQLString(sql.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func executeSQLString(_ q: String) {
        guard !q.isEmpty else { return }
        start()
        AppAmbitDb.execute(q) { r, e in
            guard let r = self.unwrap(r, e, label: "execute") else { return }
            self.ok("execute(sql) — rows_read=\(r.rowsRead)  rows_written=\(r.rowsWritten)",
                    cols: r.columns, rows: r.rows)
        }
    }

    private func executeParams() {
        start()
        AppAmbitDb.execute("SELECT * FROM tasks WHERE is_completed = ? LIMIT ?", params: [0, 10]) { r, e in
            guard let r = self.unwrap(r, e, label: "execute") else { return }
            self.ok("execute(sql, 0, 10) — pending tasks, rows_read=\(r.rowsRead)",
                    cols: r.columns, rows: r.rows)
        }
    }

    // MARK: - Schema actions

    private func createTable() {
        start()
        AppAmbitDb.execute(
            "CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, is_completed INTEGER DEFAULT 0, priority TEXT, due_date TEXT)"
        ) { r, e in self.writeResult(r, e, label: "CREATE TABLE") }
    }

    private func dropTable() {
        start()
        AppAmbitDb.execute("DROP TABLE IF EXISTS tasks") { r, e in
            self.writeResult(r, e, label: "DROP TABLE")
        }
    }

    // MARK: - Batch actions

    private func demoBatch() {
        start()
        let stmts = [
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Buy coffee", 0, "low", "2026-06-10"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Review PR", 0, "high", "2026-06-05"]),
            DbStatement.of("SELECT COUNT(*) AS total FROM tasks")
        ]
        AppAmbitDb.batch(stmts) { results, error in
            if let error = error { self.err("Batch error: \(error.localizedDescription)"); return }
            let rs = results ?? []
            let written = rs.reduce(0) { $0 + $1.rowsWritten }
            let cols = ["statement", "rows_written"]
            let rows: [[Any]] = rs.enumerated().map { i, r in [i + 1, r.rowsWritten] }
            self.ok("batch() — \(written) row(s) written across \(rs.count) statements (no transaction)",
                    cols: cols, rows: rows)
        }
    }

    private func demoBatchInTransaction() {
        start()
        let stmts = [
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Team meeting", 0, "high", "2026-06-06"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Prepare agenda", 0, "medium", "2026-06-06"])
        ]
        AppAmbitDb.batchInTransaction(stmts) { results, error in
            if let error = error { self.err("Transaction error: \(error.localizedDescription)"); return }
            let written = (results ?? []).reduce(0) { $0 + $1.rowsWritten }
            self.ok("batchInTransaction() — \(written) row(s) written, rolled back on failure",
                    cols: [], rows: [])
        }
    }

    // MARK: - Fluent SELECT actions

    private func demoFluentSelect() {
        start()
        AppAmbitDb.from("tasks")
            .select(["id", "title", "priority", "due_date"])
            .`where`("is_completed", op: "=", value: 0)
            .orderByDesc("due_date")
            .limit(5)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No pending tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "pending tasks by due date — \(maps.count) row(s)")
            }
    }

    private func demoWhereEquality() {
        start()
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 0)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No pending tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "where(is_completed, 0) — \(maps.count) task(s)")
            }
    }

    private func demoWhereIn() {
        start()
        AppAmbitDb.from("tasks")
            .whereIn("priority", values: ["high", "medium"])
            .orderBy("due_date")
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No high/medium tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "whereIn(priority, [high, medium]) — \(maps.count) row(s)")
            }
    }

    private func demoOffset() {
        start()
        AppAmbitDb.from("tasks")
            .orderBy("due_date")
            .limit(5)
            .offset(0)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No tasks found", cols: [], rows: []); return }
                self.showMaps(maps, label: "limit(5).offset(0) — page 1, \(maps.count) row(s)")
            }
    }

    private func demoFirst() {
        start()
        AppAmbitDb.from("tasks")
            .`where`("is_completed", op: "=", value: 0)
            .orderBy("due_date")
            .first { row, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                guard let row = row else {
                    self.ok("first() — no pending tasks", cols: [], rows: [])
                    return
                }
                let cols = Array(row.keys)
                self.ok("first() — next task by due date",
                        cols: cols, rows: [cols.map { row[$0] ?? NSNull() }])
            }
    }

    private func demoCount() {
        start()
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 0)
            .count { n, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                self.ok("count() — \(n) pending task(s)",
                        cols: ["pending_tasks"], rows: [[n]])
            }
    }

    // MARK: - Fluent WRITE actions

    private func demoInsert() {
        start()
        AppAmbitDb.from("tasks")
            .insert(["title": "New task", "is_completed": 0, "priority": "medium", "due_date": "2026-06-10"]) { r, e in
                self.writeResult(r, e, label: "insert()")
            }
    }

    private func demoInsertHigh() {
        start()
        AppAmbitDb.from("tasks")
            .insert(["title": "Fix critical bug", "is_completed": 0, "priority": "high", "due_date": "2026-06-05"]) { r, e in
                self.writeResult(r, e, label: "insert() high priority")
            }
    }

    private func demoInsertRawSQL() {
        start()
        AppAmbitDb.execute(
            "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
            params: ["Raw SQL insert", 0, "medium", "2026-06-12"]
        ) { r, e in self.writeResult(r, e, label: "execute() INSERT") }
    }

    private func demoInsertMany() {
        start()
        let stmts = [
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Write unit tests", 0, "high", "2026-06-07"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Update documentation", 0, "low", "2026-06-15"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Code review", 0, "medium", "2026-06-08"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Deploy to staging", 0, "high", "2026-06-09"]),
            DbStatement.of("INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Monitor metrics", 0, "low", "2026-06-20"])
        ]
        AppAmbitDb.batchInTransaction(stmts) { results, error in
            if let error = error { self.err("Error: \(error.localizedDescription)"); return }
            let written = (results ?? []).reduce(0) { $0 + $1.rowsWritten }
            self.ok("insert many — \(written) rows inserted via batch", cols: [], rows: [])
        }
    }

    private func demoUpdate() {
        start()
        AppAmbitDb.from("tasks")
            .`where`("title", value: "New task")
            .update(["is_completed": 1]) { r, e in
                self.writeResult(r, e, label: "update()")
            }
    }

    private func demoDelete() {
        start()
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 1)
            .delete { r, e in
                self.writeResult(r, e, label: "delete()")
            }
    }

    // MARK: - Typed model action

    private func demoTypedModel() {
        start()
        AppAmbitDb.from("tasks", as: TaskModel.self)
            .select(["id", "title", "is_completed", "priority", "due_date"])
            .limit(5)
            .get { tasks, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let items = tasks ?? []
                let cols = ["id", "title", "isCompleted", "priority", "dueDate"]
                let rows: [[Any]] = items.map { t in
                    [toAny(t.id), toAny(t.title), toAny(t.isCompleted), toAny(t.priority), toAny(t.dueDate)]
                }
                self.ok("from(tasks, as: TaskModel.self) — \(items.count) typed row(s)",
                        cols: cols, rows: rows)
            }
    }

    // MARK: - State helpers

    private func start() {
        isLoading = true
        statusMessage = nil
        errorMessage = nil
        resultColumns = []
        resultRows = []
    }

    private nonisolated func ok(_ message: String, cols: [String], rows: [[Any]]) {
        Task { @MainActor in
            self.isLoading = false
            self.statusMessage = message
            self.errorMessage = nil
            self.resultColumns = cols
            self.resultRows = rows
        }
    }

    private nonisolated func err(_ message: String) {
        Task { @MainActor in
            self.isLoading = false
            self.errorMessage = message
            self.statusMessage = nil
            self.resultColumns = []
            self.resultRows = []
        }
    }

    private nonisolated func unwrap(_ result: DbResult?, _ error: Error?, label: String) -> DbResult? {
        if let error = error { err("ERROR (\(label)): \(error.localizedDescription)"); return nil }
        guard let r = result else { err("\(label): no result"); return nil }
        if r.hasError { err("DB ERROR (\(label)): \(r.error ?? "")"); return nil }
        return r
    }

    private nonisolated func writeResult(_ result: DbResult?, _ error: Error?, label: String) {
        guard let r = unwrap(result, error, label: label) else { return }
        ok("\(label) OK — rows_read=\(r.rowsRead)  rows_written=\(r.rowsWritten)", cols: [], rows: [])
    }

    private nonisolated func showMaps(_ maps: [[String: Any]], label: String) {
        let cols = maps.first.map { Array($0.keys) } ?? []
        let rows: [[Any]] = maps.map { row in cols.map { row[$0] ?? NSNull() } }
        ok(label, cols: cols, rows: rows)
    }
}

private func toAny<T>(_ opt: T?) -> Any {
    opt.map { $0 as Any } ?? NSNull()
}
