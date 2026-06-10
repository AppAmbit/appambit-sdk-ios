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
    @State private var selectedIndex = 0

    private var demoLabels: [String] { demos.map(\.0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // SQL field
                TextField("SQL", text: $sql, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(.caption, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(10)
                    .background(Color(.systemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))

                // Dropdown + Run
                HStack(spacing: 8) {
                    Menu {
                        ForEach(demoLabels.indices, id: \.self) { i in
                            Button(demoLabels[i]) { selectedIndex = i }
                        }
                    } label: {
                        HStack {
                            Text(demoLabels[selectedIndex])
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(.systemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 1))
                    }

                    Button {
                        reset()
                        isLoading = true
                        demos[selectedIndex].1()
                    } label: {
                        Label("Run", systemImage: "play.fill")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                }

                // Status banners
                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(Color(red: 0.11, green: 0.37, blue: 0.13))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(red: 0.91, green: 0.96, blue: 0.91))
                        .cornerRadius(8)
                }

                if let errMsg = errorMessage {
                    Text(errMsg)
                        .font(.caption)
                        .foregroundColor(Color(red: 0.78, green: 0.16, blue: 0.16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(red: 1.0, green: 0.92, blue: 0.92))
                        .cornerRadius(8)
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }

                if !resultColumns.isEmpty {
                    ResultCard(columns: resultColumns, rows: resultRows)
                }
            }
            .padding(12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Database")
    }

    // MARK: - Demos

    private var demos: [(String, () -> Void)] {[
        ("Raw SQL → execute(sql)",                          { self.demoExecute() }),
        ("Raw SQL → execute(sql, params)",                  { self.demoExecuteParams() }),
        ("Schema → CREATE TABLE tasks",                     { self.demoCreateTable() }),
        ("Schema → DROP TABLE tasks",                       { self.demoDropTable() }),
        ("Batch → batch()",                                 { self.demoBatch() }),
        ("Batch → batchInTransaction()",                    { self.demoBatchInTransaction() }),
        ("Fluent SELECT → select+where+orderByDesc+limit",  { self.demoFluentSelect() }),
        ("Fluent SELECT → where(col, val)",                 { self.demoWhereEquality() }),
        ("Fluent SELECT → whereIn()",                       { self.demoWhereIn() }),
        ("Fluent SELECT → limit+offset",                    { self.demoOffset() }),
        ("Fluent SELECT → first()",                         { self.demoFirst() }),
        ("Fluent SELECT → count()",                         { self.demoCount() }),
        ("Fluent WRITE → insert()",                         { self.demoInsert() }),
        ("Fluent WRITE → insert() high priority",           { self.demoInsertHigh() }),
        ("Fluent WRITE → insert() raw SQL",                 { self.demoInsertRawSQL() }),
        ("Fluent WRITE → insert many (batch)",              { self.demoInsertMany() }),
        ("Fluent WRITE → update()",                         { self.demoUpdate() }),
        ("Fluent WRITE → delete()",                         { self.demoDelete() }),
        ("Typed Model → from(tasks, as: TaskModel.self)",   { self.demoTypedModel() }),
        ("Preset → List tables",                            { self.demoPresetTables() }),
        ("Preset → SELECT * WHERE priority='high'",         { self.demoPresetHighPriority() }),
    ]}

    // MARK: - Raw SQL

    private func demoExecute() {
        let q = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { ok("Empty SQL", cols: [], rows: []); return }
        AppAmbitDb.execute(q) { r, e in
            guard let r = self.unwrap(r, e, label: "execute") else { return }
            self.ok("execute(sql) — rows_read=\(r.rowsRead)  rows_written=\(r.rowsWritten)",
                    cols: r.columns, rows: r.rows)
        }
    }

    private func demoExecuteParams() {
        AppAmbitDb.execute("SELECT * FROM tasks WHERE is_completed = ? LIMIT ?", params: [0, 10]) { r, e in
            guard let r = self.unwrap(r, e, label: "execute") else { return }
            self.ok("execute(sql, 0, 10) — pending tasks, rows_read=\(r.rowsRead)",
                    cols: r.columns, rows: r.rows)
        }
    }

    // MARK: - Schema

    private func demoCreateTable() {
        AppAmbitDb.execute(
            "CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, is_completed INTEGER DEFAULT 0, priority TEXT, due_date TEXT)"
        ) { r, e in self.writeResult(r, e, label: "CREATE TABLE") }
    }

    private func demoDropTable() {
        AppAmbitDb.execute("DROP TABLE IF EXISTS tasks") { r, e in
            self.writeResult(r, e, label: "DROP TABLE")
        }
    }

    // MARK: - Batch

    private func demoBatch() {
        let stmts = [
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Buy coffee", 0, "low", "2026-06-10"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Review PR", 0, "high", "2026-06-05"]),
            DbStatement(sql: "SELECT COUNT(*) AS total FROM tasks")
        ]
        AppAmbitDb.batch(stmts) { results, error in
            if let error = error { self.err("Batch error: \(error.localizedDescription)"); return }
            let rs = results ?? []
            let written = rs.reduce(0) { $0 + $1.rowsWritten }
            let rows: [[Any]] = rs.enumerated().map { i, r in [i + 1, r.rowsWritten, r.rowsRead] }
            self.ok("batch() — \(written) row(s) written across \(rs.count) statements (no transaction)",
                    cols: ["statement", "rows_written", "rows_read"], rows: rows)
        }
    }

    private func demoBatchInTransaction() {
        let stmts = [
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Team meeting", 0, "high", "2026-06-06"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Prepare agenda", 0, "medium", "2026-06-06"])
        ]
        AppAmbitDb.batchInTransaction(stmts) { results, error in
            if let error = error { self.err("Transaction error: \(error.localizedDescription)"); return }
            let rs = results ?? []
            let written = rs.reduce(0) { $0 + $1.rowsWritten }
            let rows: [[Any]] = rs.enumerated().map { i, r in [i + 1, r.rowsWritten] }
            self.ok("batchInTransaction() — \(written) row(s) written, rolled back on any failure",
                    cols: ["statement", "rows_written"], rows: rows)
        }
    }

    // MARK: - Fluent SELECT

    private func demoFluentSelect() {
        AppAmbitDb.from("tasks")
            .select(["id", "title", "priority", "due_date"])
            .`where`("is_completed", op: "=", value: 0)
            .orderByDesc("due_date")
            .limit(5)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No pending tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "from().select().where().orderByDesc().limit(5) — \(maps.count) row(s)")
            }
    }

    private func demoWhereEquality() {
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 0)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No pending tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "where(is_completed, 0) — \(maps.count) pending task(s)")
            }
    }

    private func demoWhereIn() {
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
        AppAmbitDb.from("tasks")
            .orderBy("due_date")
            .limit(5)
            .offset(0)
            .get { maps, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                let maps = maps ?? []
                if maps.isEmpty { self.ok("No tasks", cols: [], rows: []); return }
                self.showMaps(maps, label: "limit(5).offset(0) — page 1, \(maps.count) row(s)")
            }
    }

    private func demoFirst() {
        AppAmbitDb.from("tasks")
            .`where`("is_completed", op: "=", value: 0)
            .orderBy("due_date")
            .first { row, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                guard let row = row else {
                    self.ok("first() — No pending tasks", cols: [], rows: [])
                    return
                }
                let cols = Array(row.keys)
                self.ok("first() — next task due",
                        cols: cols, rows: [cols.map { row[$0] ?? NSNull() }])
            }
    }

    private func demoCount() {
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 0)
            .count { n, error in
                if let error = error { self.err("Error: \(error.localizedDescription)"); return }
                self.ok("count() — \(n) pending task(s)",
                        cols: ["pending_tasks"], rows: [[n]])
            }
    }

    // MARK: - Fluent WRITE

    private func demoInsert() {
        AppAmbitDb.from("tasks")
            .insert(["title": "New task", "is_completed": 0, "priority": "medium", "due_date": "2026-06-10"]) { r, e in
                guard let r = self.unwrap(r, e, label: "insert()") else { return }
                self.ok("insert() — task created, rows_written=\(r.rowsWritten)",
                        cols: ["rows_written"], rows: [[r.rowsWritten]])
            }
    }

    private func demoInsertHigh() {
        AppAmbitDb.from("tasks")
            .insert(["title": "Fix critical bug", "is_completed": 0, "priority": "high", "due_date": "2026-06-05"]) { r, e in
                guard let r = self.unwrap(r, e, label: "insert()") else { return }
                self.ok("insert() high priority — task created, rows_written=\(r.rowsWritten)",
                        cols: ["rows_written"], rows: [[r.rowsWritten]])
            }
    }

    private func demoInsertRawSQL() {
        AppAmbitDb.execute(
            "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
            params: ["Raw SQL insert", 0, "medium", "2026-06-12"]
        ) { r, e in
            guard let r = self.unwrap(r, e, label: "execute() INSERT") else { return }
            self.ok("execute() INSERT OK — rows_written=\(r.rowsWritten)",
                    cols: ["rows_written"], rows: [[r.rowsWritten]])
        }
    }

    private func demoInsertMany() {
        let stmts = [
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Write unit tests", 0, "high", "2026-06-07"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Update documentation", 0, "low", "2026-06-15"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Code review", 0, "medium", "2026-06-08"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Deploy to staging", 0, "high", "2026-06-09"]),
            DbStatement(sql: "INSERT INTO tasks (title, is_completed, priority, due_date) VALUES (?, ?, ?, ?)",
                           params: ["Monitor metrics", 0, "low", "2026-06-20"])
        ]
        AppAmbitDb.batchInTransaction(stmts) { results, error in
            if let error = error { self.err("Error: \(error.localizedDescription)"); return }
            let written = (results ?? []).reduce(0) { $0 + $1.rowsWritten }
            self.ok("insert many — \(written) rows inserted via batch",
                    cols: ["rows_inserted"], rows: [[written]])
        }
    }

    private func demoUpdate() {
        AppAmbitDb.from("tasks")
            .`where`("title", value: "New task")
            .update(["is_completed": 1]) { r, e in
                guard let r = self.unwrap(r, e, label: "update()") else { return }
                self.ok("update() — task marked as completed, rows_written=\(r.rowsWritten)",
                        cols: ["rows_written"], rows: [[r.rowsWritten]])
            }
    }

    private func demoDelete() {
        AppAmbitDb.from("tasks")
            .`where`("is_completed", value: 1)
            .delete { r, e in
                guard let r = self.unwrap(r, e, label: "delete()") else { return }
                self.ok("delete() — completed tasks deleted, rows_written=\(r.rowsWritten)",
                        cols: ["rows_written"], rows: [[r.rowsWritten]])
            }
    }

    // MARK: - Typed Model

    private func demoTypedModel() {
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

    // MARK: - Presets

    private func demoPresetTables() {
        let q = "SELECT name FROM sqlite_master WHERE type = 'table'"
        Task { @MainActor in sql = q }
        AppAmbitDb.execute(q) { r, e in
            guard let r = self.unwrap(r, e, label: "sqlite_master") else { return }
            self.ok("sqlite_master tables — \(r.rowsRead) row(s)", cols: r.columns, rows: r.rows)
        }
    }

    private func demoPresetHighPriority() {
        let q = "SELECT * FROM tasks WHERE priority = 'high'"
        Task { @MainActor in sql = q }
        AppAmbitDb.execute(q) { r, e in
            guard let r = self.unwrap(r, e, label: "execute") else { return }
            self.ok("tasks WHERE priority='high' — \(r.rowsRead) row(s)", cols: r.columns, rows: r.rows)
        }
    }

    // MARK: - State helpers

    private func reset() {
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
        if let error = error { err("Error (\(label)): \(error.localizedDescription)"); return nil }
        guard let r = result else { err("\(label): no result"); return nil }
        if r.hasError { err("DB error (\(label)): \(r.error ?? "")"); return nil }
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

// MARK: - Result Card

private struct ResultCard: View {
    let columns: [String]
    let rows: [[Any]]

    private let colWidth: CGFloat = 140

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(columns.indices, id: \.self) { ci in
                        Text(columns[ci])
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color(red: 0.10, green: 0.14, blue: 0.49))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(width: colWidth, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.88, green: 0.91, blue: 0.98))
            }

            Rectangle()
                .fill(Color(red: 0.63, green: 0.73, blue: 0.93).opacity(0.5))
                .frame(height: 1)

            if rows.isEmpty {
                Text("(no rows)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(rows.indices, id: \.self) { ri in
                            HStack(spacing: 0) {
                                ForEach(columns.indices, id: \.self) { ci in
                                    let val: Any = ci < rows[ri].count ? rows[ri][ci] : NSNull()
                                    let isNull = val is NSNull
                                    Text(verbatim: isNull ? "null" : String(describing: val))
                                        .font(.system(.caption, design: .monospaced))
                                        .italic(isNull)
                                        .foregroundColor(isNull ? .secondary : .primary)
                                        .lineLimit(2)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .frame(width: colWidth, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ri % 2 == 0
                                ? Color(.systemBackground)
                                : Color(.systemGray6).opacity(0.45))

                            if ri < rows.count - 1 {
                                Rectangle()
                                    .fill(Color(.systemGray4).opacity(0.5))
                                    .frame(height: 0.5)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)

                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 0.5)

                Text("\(rows.count) row\(rows.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 1)
    }
}

private func toAny<T>(_ opt: T?) -> Any {
    opt.map { $0 as Any } ?? NSNull()
}
