import SwiftUI
import AppAmbit
import AppAmbitPushNotifications
import UserNotifications

struct CloudCodeView: View {
    @State private var taskTitle = "Buy coffee"
    @State private var taskId = ""
    @State private var postUUID = ""
    @State private var publishTitle = "Cloud Code sample post"
    @State private var publishBody = "Published through an HTTP Cloud Function."
    @State private var isRunning = false
    @State private var lastResultDemoID: String?
    @State private var resultText = "No Cloud Code request yet."
    @State private var resultTitle = "Latest result"
    @State private var isResultExpanded = true
    @State private var pendingConfirmation: CloudCodeDemoAction?
    @State private var pendingConfirmationDemoID: String?
    @State private var databaseStatus = "Not available"
    @State private var cmsStatus = "Not available"
    @State private var databaseAvailable = false
    @State private var cmsAvailable = false
    @State private var isVerifyingBackend = false

    private let sectionNames = ["Database", "CMS", "Push", "HTTP"]

    private let demos: [CloudCodeDemo] = [
        CloudCodeDemo(id: "create-task", section: "Database", title: "Create task", slug: "cloud-demo-create-task", detail: "Insert a task for the signed-in consumer.", prerequisite: "cloud_demo_tasks", action: .createTask),
        CloudCodeDemo(id: "list-tasks", section: "Database", title: "List tasks", slug: "cloud-demo-list-tasks", detail: "Read the current consumer's tasks.", prerequisite: "cloud_demo_tasks", action: .listTasks),
        CloudCodeDemo(id: "complete-task", section: "Database", title: "Complete task", slug: "cloud-demo-complete-task", detail: "Update one task with consumer ownership.", prerequisite: "Task id", action: .completeTask),
        CloudCodeDemo(id: "delete-task", section: "Database", title: "Delete task", slug: "cloud-demo-delete-task", detail: "Delete one task owned by the consumer.", prerequisite: "Task id + confirmation", action: .deleteTask),
        CloudCodeDemo(id: "order", section: "Database", title: "Create idempotent order", slug: "cloud-demo-create-order", detail: "Create an order without duplicate idempotency keys.", prerequisite: "cloud_demo_orders", action: .createOrder),
        CloudCodeDemo(id: "summary", section: "Database", title: "Dashboard summary", slug: "cloud-demo-dashboard-summary", detail: "Combine Database and CMS in one typed response.", prerequisite: "Database + CMS", action: .summary),
        CloudCodeDemo(id: "create-sample-content", section: "CMS", title: "Create sample content", slug: "cloud-demo-publish-post", detail: "Create a published CMS entry.", prerequisite: "Confirmation", action: .publishPost),
        CloudCodeDemo(id: "read-posts", section: "CMS", title: "Read CMS posts", slug: "cloud-demo-read-posts", detail: "List published entries using only CMS data.", prerequisite: "cloud_code_demo_posts", action: .readPosts),
        CloudCodeDemo(id: "push", section: "Push", title: "Send push notification", slug: "cloud-demo-send-push", detail: "Send a notification to all consumers.", prerequisite: "Permission + APNs/FCM", action: .push),
        CloudCodeDemo(id: "inspector", section: "HTTP", title: "Inspect HTTP context", slug: "cloud-demo-http-inspector", detail: "Inspect method, query, body and consumer context.", prerequisite: "HTTP trigger", action: .inspector),
        CloudCodeDemo(id: "json-values", section: "HTTP", title: "JSON values", slug: "cloud-demo-json-values", detail: "Return common JSON value types.", prerequisite: "HTTP trigger", action: .jsonValues),
        CloudCodeDemo(id: "null-contract", section: "HTTP", title: "Null contract", slug: "cloud-demo-null-contract", detail: "Compare raw null and an explicit value.", prerequisite: "HTTP trigger", action: .nullContract),
        CloudCodeDemo(id: "response-shapes", section: "HTTP", title: "HTTP response shapes", slug: "cloud-demo-response-shapes", detail: "Demonstrate statuses, body and headers.", prerequisite: "HTTP trigger", action: .responseShapes),
        CloudCodeDemo(id: "controlled-error", section: "HTTP", title: "Controlled error", slug: "cloud-demo-error-response", detail: "Return a safe client error response.", prerequisite: "HTTP trigger", action: .controlledError),
        CloudCodeDemo(id: "timeout", section: "HTTP", title: "Backend timeout", slug: "cloud-demo-timeout-10s", detail: "Observe the configured function timeout.", prerequisite: "Function timeout = 10 s", action: .timeout),
        CloudCodeDemo(id: "runtime-context", section: "HTTP", title: "Runtime context", slug: "cloud-demo-runtime-context", detail: "Use environment values, secrets and logs safely.", prerequisite: "DEMO_REGION + DEMO_SECRET", action: .runtimeContext),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                     GroupBox("Database") {
                         VStack(alignment: .leading, spacing: 8) {
                             setupRequirement("Create Database first", tint: .blue)
                             HStack(spacing: 8) {
                                 Label(databaseStatus, systemImage: databaseAvailable ? "checkmark.circle.fill" : "xmark.circle")
                                     .font(.caption.weight(.semibold))
                                     .foregroundColor(databaseAvailable ? .green : .secondary)
                                 Spacer()
                                 if isVerifyingBackend {
                                     ProgressView()
                                         .controlSize(.small)
                                 }
                                  Button {
                                      runOrConfirm(.setupDatabase, demoID: "setup-database")
                                  } label: {
                                      Label("cloud-demo-setup-database", systemImage: "play.fill")
                                  }
                                 .buttonStyle(.borderedProminent)
                                 .disabled(isRunning || isVerifyingBackend)
                             }
                             resultCard(for: "setup-database")
                         }
                         .frame(maxWidth: .infinity, alignment: .leading)
                     }

                      GroupBox("CMS") {
                          VStack(alignment: .leading, spacing: 10) {
                              setupRequirement("Create Content Type first", tint: .purple)
                             HStack(spacing: 8) {
                                 Label(cmsStatus, systemImage: cmsAvailable ? "checkmark.circle.fill" : "xmark.circle")
                                     .font(.caption.weight(.semibold))
                                     .foregroundColor(cmsAvailable ? .green : .secondary)
                                 Spacer()
                                 if isVerifyingBackend {
                                     ProgressView()
                                         .controlSize(.small)
                                 }
                             }
                         }
                         .frame(maxWidth: .infinity, alignment: .leading)
                     }

                     ForEach(sectionNames, id: \.self) { section in
                         VStack(alignment: .leading, spacing: 8) {
                             Text(section)
                                 .font(.headline)
                                 .padding(.top, 2)

                             if section == "Database" {
                                 VStack(spacing: 10) {
                                     TextField("Task title", text: $taskTitle)
                                         .textFieldStyle(.roundedBorder)
                                     TextField("Task id for update/delete", text: $taskId)
                                         .keyboardType(.numberPad)
                                         .textFieldStyle(.roundedBorder)
                                 }
                             }

                             if section == "CMS" {
                                 VStack(spacing: 10) {
                                     TextField("CMS post UUID", text: $postUUID)
                                         .textFieldStyle(.roundedBorder)
                                     TextField("Sample title", text: $publishTitle)
                                         .textFieldStyle(.roundedBorder)
                                     TextField("Sample body", text: $publishBody, axis: .vertical)
                                         .lineLimit(3...6)
                                         .textFieldStyle(.roundedBorder)
                                 }
                             }

                             ForEach(demos.filter { $0.section == section }) { demo in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .firstTextBaseline) {
                                         VStack(alignment: .leading, spacing: 2) {
                                             Text(demo.slug)
                                                 .font(.subheadline.weight(.semibold))
                                             Text(demo.detail)
                                                 .font(.caption)
                                                 .foregroundColor(.secondary)
                                        }
                                        Spacer(minLength: 8)
                                        if let action = demo.action {
                                            Button {
                                                runOrConfirm(action, demoID: demo.id)
                                            } label: {
                                                Label("Run", systemImage: "play.fill")
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .frame(minWidth: 44, minHeight: 44)
                                            .disabled(isRunning)
                                        } else {
                                            Text("Dashboard")
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                     Text(demo.prerequisite)
                                         .font(.caption2.monospaced())
                                         .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                 resultCard(for: demo.id)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Cloud Code")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                 if databaseStatus == "Not available" && cmsStatus == "Not available" {
                     verifyBackend()
                 }
            }
            .overlay {
                if isRunning {
                    ProgressView("Calling Cloud Code...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Confirm Cloud Code action", isPresented: confirmationBinding) {
                Button("Cancel", role: .cancel) {
                    pendingConfirmation = nil
                    pendingConfirmationDemoID = nil
                }
                Button("Run", role: .destructive) {
                    let action = pendingConfirmation
                    let demoID = pendingConfirmationDemoID
                    pendingConfirmation = nil
                    pendingConfirmationDemoID = nil
                    if let action, let demoID { run(action, demoID: demoID) }
                }
            } message: {
                Text("This calls a real backend operation. Continue only if the required service is configured.")
            }
        }
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingConfirmation != nil },
            set: {
                if !$0 {
                    pendingConfirmation = nil
                    pendingConfirmationDemoID = nil
                }
            }
        )
    }

    private func setupRequirement(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func verifyBackend() {
        guard !isVerifyingBackend else { return }
        isVerifyingBackend = true
        databaseStatus = "Checking..."
        cmsStatus = "Checking..."
        CloudCode.call(
            "cloud-demo-dashboard-summary",
            method: .get,
            query: nil,
            body: nil,
            headers: ["X-Sample-Client": "swift"]
        ) { response, error in
            DispatchQueue.main.async {
                isVerifyingBackend = false
                guard let response, response.statusCode == 200,
                      let payload = response.data as? [String: Any] else {
                    databaseAvailable = false
                    cmsAvailable = false
                    databaseStatus = "Not available"
                    cmsStatus = "Not available"
                    return
                }

                databaseAvailable = payload["task_count"] != nil
                cmsAvailable = payload["posts"] != nil
                databaseStatus = databaseAvailable ? "Available" : "Not available"
                cmsStatus = cmsAvailable ? "Available" : "Not available"
                _ = error
            }
        }
    }

    private func runOrConfirm(_ action: CloudCodeDemoAction, demoID: String) {
        switch action {
        case .deleteTask, .publishPost, .push:
            pendingConfirmation = action
            pendingConfirmationDemoID = demoID
        default:
            run(action, demoID: demoID)
        }
    }

    private func run(_ action: CloudCodeDemoAction, demoID: String) {
        guard !isRunning else { return }
        lastResultDemoID = demoID
        if [.completeTask, .deleteTask].contains(where: { sameAction($0, action) }), Int(taskId) == nil {
            resultText = "Enter a numeric task id first."
            resultTitle = "Input required"
            isResultExpanded = true
            return
        }

        let configuration = requestConfiguration(for: action)
        isRunning = true
        resultTitle = "Latest result · \(configuration.slug)"
        resultText = "Calling \(configuration.slug)..."
        isResultExpanded = true
        let started = Date()

        if action == .push {
            ensurePushReady { granted in
                DispatchQueue.main.async {
                    guard self.isRunning else { return }
                    if granted {
                        self.call(action, configuration: configuration, started: started)
                    } else {
                        self.isRunning = false
                        self.resultText = "Notification permission is required. Enable notifications in Settings and try again."
                    }
                }
            }
        } else {
            call(action, configuration: configuration, started: started)
        }
    }

    private func call(_ action: CloudCodeDemoAction, configuration: (slug: String, method: CloudCodeHttpMethod, query: [String: String]?, body: [String: Any]?, headers: [String: String]?), started: Date) {
        if action == .summary {
            CloudCode.call(
                configuration.slug,
                method: configuration.method,
                query: configuration.query,
                body: configuration.body,
                headers: configuration.headers,
                as: DashboardSummary.self
            ) { result, error in
                DispatchQueue.main.async {
                    self.finishTyped(result: result, error: error, started: started)
                }
            }
            return
        }

        CloudCode.call(
            configuration.slug,
            method: configuration.method,
            query: configuration.query,
            body: configuration.body,
            headers: configuration.headers
        ) { response, error in
            let elapsed = Date().timeIntervalSince(started)
            DispatchQueue.main.async {
                self.isRunning = false
                self.resultText = self.format(response: response, error: error, elapsed: elapsed)
            }
        }
    }

    private func ensurePushReady(completion: @escaping (Bool) -> Void) {
        // Keep this path safe if the host app did not initialize Push yet.
        PushNotifications.start(debugMode: true)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let hasPermission = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional

            DispatchQueue.main.async {
                if hasPermission {
                    PushNotifications.setNotificationsEnabled(true)
                    completion(true)
                    return
                }

                if settings.authorizationStatus == .notDetermined {
                    PushNotifications.requestNotificationPermission { granted in
                        DispatchQueue.main.async {
                            if granted {
                                PushNotifications.setNotificationsEnabled(true)
                            }
                            completion(granted)
                        }
                    }
                    return
                }

                completion(false)
            }
        }
    }

    @ViewBuilder
    private func resultCard(for demoID: String) -> some View {
        if lastResultDemoID == demoID {
            GroupBox {
                DisclosureGroup(isExpanded: $isResultExpanded) {
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        Text(resultText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.top, 6)
                    }
                    .frame(maxHeight: 240)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resultTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(isResultExpanded ? "Tap to collapse" : "Tap to expand the response")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func sameAction(_ lhs: CloudCodeDemoAction, _ rhs: CloudCodeDemoAction) -> Bool {
        switch (lhs, rhs) {
        case (.completeTask, .completeTask), (.deleteTask, .deleteTask): return true
        default: return false
        }
    }

    private func requestConfiguration(for action: CloudCodeDemoAction) -> (slug: String, method: CloudCodeHttpMethod, query: [String: String]?, body: [String: Any]?, headers: [String: String]?) {
        let taskValue = Int(taskId) ?? 0
        let headers = ["X-Sample-Client": "swift"]
        switch action {
        case .setupDatabase: return ("cloud-demo-setup-database", .post, nil, nil, headers)
        case .createTask: return ("cloud-demo-create-task", .post, nil, ["title": taskTitle], headers)
        case .listTasks: return ("cloud-demo-list-tasks", .get, ["limit": "20"], nil, headers)
        case .completeTask: return ("cloud-demo-complete-task", .patch, nil, ["task_id": taskValue], headers)
        case .deleteTask: return ("cloud-demo-delete-task", .delete, nil, ["task_id": taskValue], headers)
        case .inspector: return ("cloud-demo-http-inspector", .post, ["source": "swift"], ["message": "hello", "count": 2], headers)
        case .jsonValues: return ("cloud-demo-json-values", .post, nil, nil, headers)
        case .nullContract: return ("cloud-demo-null-contract", .get, nil, nil, headers)
        case .responseShapes: return ("cloud-demo-response-shapes", .post, nil, nil, headers)
        case .controlledError: return ("cloud-demo-error-response", .post, nil, ["invalid": true], headers)
        case .timeout: return ("cloud-demo-timeout-10s", .get, nil, nil, headers)
        case .readPosts: return ("cloud-demo-read-posts", .get, postUUID.isEmpty ? nil : ["uuid": postUUID], nil, headers)
        case .publishPost: return ("cloud-demo-publish-post", .post, nil, ["title": publishTitle, "body": publishBody], headers)
        case .runtimeContext: return ("cloud-demo-runtime-context", .get, nil, nil, headers)
        case .push: return ("cloud-demo-send-push", .post, nil, ["title": "Cloud Code demo", "body": "Push from Swift sample"], headers)
        case .createOrder: return ("cloud-demo-create-order", .post, nil, ["idempotency_key": UUID().uuidString, "amount": 100], headers)
        case .summary: return ("cloud-demo-dashboard-summary", .get, nil, nil, headers)
        }
    }

    private func finishTyped(result: CloudCodeResult<DashboardSummary>?, error: CloudCodeError?, started: Date) {
        let elapsed = Date().timeIntervalSince(started)
        DispatchQueue.main.async {
            isRunning = false
            if let result {
                let data: [String: Any] = [
                    "task_count": result.data.taskCount ?? NSNull(),
                    "posts": result.data.posts?.map { $0.toAny() } ?? []
                ]
                resultText = "HTTP \(result.statusCode)\nDuration: \(formatDuration(elapsed))\nrequestId: \(result.requestId ?? "none")\nBody: \(jsonText(data))"
            } else if let error {
                resultText = "Duration: \(formatDuration(elapsed))\nError: \(error.localizedDescription)"
            } else {
                resultText = "HTTP 204\nDuration: \(formatDuration(elapsed))\nBody: No content"
            }
        }
    }

    private func format(response: CloudCodeResponse?, error: Error?, elapsed: TimeInterval) -> String {
        if let response {
            return "HTTP \(response.statusCode)\nDuration: \(formatDuration(elapsed))\nrequestId: \(response.requestId ?? "none")\nBody: \(jsonText(response.data))"
        }
        if let cloudError = error as? CloudCodeError {
            switch cloudError {
            case .http(_, let body, let rawBody, let requestId):
                let bodyText = body.map { jsonText($0.toAny()) } ?? rawBody ?? "none"
                return "Duration: \(formatDuration(elapsed))\nrequestId: \(requestId ?? "none")\nHTTP error body: \(bodyText)\nError: \(cloudError.localizedDescription)"
            default:
                break
            }
        }
        return "Duration: \(formatDuration(elapsed))\nError: \(error?.localizedDescription ?? "Unknown error")"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.2f s", duration)
    }

    private func jsonText(_ value: Any) -> String {
        if value is NSNull { return "null" }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }
        return string
    }
}
