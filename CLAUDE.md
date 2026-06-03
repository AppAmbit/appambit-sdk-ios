# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

### Run all tests (SPM — preferred)
```bash
swift test --package-path AppAmbitSdk -c debug
```

### Run a single test class
```bash
swift test --package-path AppAmbitSdk -c debug --filter AnalyticsTests
```

### Build via Xcode workspace
```bash
xcodebuild -workspace AppAmbit.xcodeproj/project.xcworkspace \
  -scheme AppAmbit.App.Swift \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  CODE_SIGNING_ALLOWED=NO build
```

### CocoaPods (consumer-side validation)
```bash
pod lib lint AppAmbitSdk/AppAmbitSdk.podspec --allow-warnings
pod lib lint Push/AppAmbitPushNotifications/AppAmbitPushNotifications.podspec --allow-warnings
```

## Architecture

The repo contains two independent Swift packages and one Xcode project:

| Path | Package / Pod | Role |
|---|---|---|
| `AppAmbitSdk/` | `AppAmbit` | Core SDK — analytics, sessions, crashes, remote config, CMS, breadcrumbs |
| `Push/AppAmbitPushNotifications/` | `AppAmbitPushNotifications` | Push SDK — APNs token capture, notification listener, NSE base class |
| `AppAmbit.xcodeproj` | — | Sample apps (Swift & ObjC) and test host |

`AppAmbitPushNotifications` depends on `AppAmbit` via a local path reference (`../../AppAmbitSdk`).

### Core SDK internals (`AppAmbitSdk/Sources/`)

**Entry point**: `AppAmbit.start(appKey:)` — singleton, idempotent. Initialises `ServiceContainer`, registers crash handler, swizzles `UIViewController` lifecycle for automatic breadcrumbs, and starts network monitoring via `NWPathMonitor`.

**Startup sequence**: `AppAmbit.start` → `ServiceContainer.shared` lazily inits → `ConsumerService.createConsumer` → on success token stored → `sendAllPendingData()` drains queues (sessions → events → crashes → breadcrumbs). Network changes re-trigger `sendAllPendingData()` via `NWPathMonitor`.

**`ServiceContainer`** — lazy singleton providing three shared services:
- `ApiService` (`AppAmbitApiService`) — HTTP client, holds the auth token
- `StorageService` (`StorableService`) — SQLite-backed persistence via `DataStore`
- `ReachabilityService` — network reachability

**Feature modules** — each is a static-method namespace (`@objcMembers public final class`) initialised by `AppAmbit` with injected `ApiService`/`StorageService`:
- `Analytics` — `trackEvent`, `setUserId`, `setEmail`, manual session control
- `SessionManager` — start/end/batch session lifecycle
- `RemoteConfig` — fetch & type-safe getters (`getString`, `getBoolean`, `getLong`, `getDouble`)
- `BreadcrumbManager` — automatic VC appear/disappear + manual breadcrumbs, persisted to file between crashes
- `Crashes` — uncaught exception capture via `CrashHandler`; crash file read on next launch
- `Logging` — structured error logs
- `Cms` — CMS content fetch (no local cache; fetches fresh every call)

**Concurrency model**: work runs on named `DispatchQueue`s in `Queues` — `state` (singleton guards), `db` (SQLite), `diskRoot`/`crashFiles` (file I/O; `crashFiles` targets `diskRoot`), `batch` (upload batches), `netDecode` (concurrent JSON decode), `token` (concurrent reader/writer for auth token). All public APIs are `@unchecked Sendable`; Swift 6 strict concurrency is enabled (`swift-tools-version: 6.0`).

**Offline flow**: when network is lost the SDK persists data to SQLite (events, sessions, breadcrumbs) and to files (crash state, breadcrumb stream). On next network restore or app foreground, `sendAllPendingData()` drains the queues in order: sessions → events → crashes → breadcrumbs.

**Breadcrumb crash-stream**: `BreadcrumbManager.streamCrashSessionsOnly` controls whether breadcrumbs are loaded from file only when a crash flag exists (leaner) or always. Breadcrumb state is saved to a flat file on `onPause`/`onSleep` and loaded back on resume/foreground.

**ViewController swizzling**: `AppAmbit` swizzles `viewDidAppear` and `viewDidDisappear` on `UIViewController` to emit breadcrumbs automatically. It skips navigation controllers, tab bar controllers, alert controllers, and internal `_UI*` classes. The display name is resolved from `navigationItem.title`.

### Storage layer (`AppAmbitSdk/Sources/Services/Storage/`)

**`DataStore`** — raw SQLite wrapper. `createTables()` runs on init; schema changes go here as private `migrate*` methods (see `migrateSecretsTable()` for the pattern: check column/table existence, then `ALTER`/`DROP`).

**`StorableService`** — concrete `StorageService` implementation. Add new persistence operations here and declare them in `Services/Protocols/StorageService.swift`.

**Table configurations** (`Storage/Configuration/`) — each entity owns a `createTable` SQL string and a `Column` enum. Add a new file here when adding a new persistent entity.

### Network layer (`AppAmbitSdk/Sources/Services/`)

**`ApiService` protocol** (`Protocols/ApiService.swift`) — implemented by `AppAmbitApiService`. All feature modules receive it via injection; in tests `StubApiService` is used.

**Endpoints** (`Services/Endpoints/`) — each endpoint is a struct conforming to `Endpoint`. `BaseEndpoint` handles auth header injection. Add a new file per endpoint.

**`ConsumerService`** — handles device/user registration (`createConsumer`) and push state sync (`updateConsumer`). Called from `AppAmbit.onStart()` and by the Push SDK after APNs token receipt. Never sends `pushEnabled=true` without a device token.

### Push SDK (`Push/AppAmbitPushNotifications/Sources/`)

Two distinct components:
1. **`AppAmbitNotificationService`** — `UNNotificationServiceExtension` base class for the Notification Service Extension target. Runs in a separate process; override `handlePayload` to inspect/mutate content.
2. **`PushNotifications`** — app-side API for token registration, permission requests, and the notification listener (`.foreground` / `.opened` states). APNs token is captured automatically via method swizzling.

ObjC consumers of the NSE use `AppAmbitNotificationProcessor` (a plain class, not a restricted Swift type) since SPM dynamic library Swift classes cannot be subclassed from ObjC.

### Testing

Tests live in `AppAmbitSdk/Tests/`. `TestDoubles.swift` defines:
- `StubApiService` — records calls by endpoint type, returns stubbed `ApiResult<T>`
- `InMemoryStorage` — thread-safe in-memory `StorageService`
- `TestURLProtocol` — intercepts `URLSession` requests at the protocol level
- `waitAsync` / `waitAsyncError` — `XCTestCase` helpers for callback-based async code

Tests inject doubles directly into the feature-module singletons via `initialize(apiService:storageService:)`.

## Key constraints

- iOS 12.0 minimum deployment target; Swift 5.7 minimum language version.
- Public API must remain fully Objective-C compatible (`@objcMembers`, `@objc` overloads, `NSObject` subclass).
- The Push SDK pod (`AppAmbitPushNotificationsExtension`) ships a separate extension-safe slice — changes to Push sources must not introduce `UIApplication` or other APIs forbidden in NSE targets.
- Crashes upload on the **next launch**, not immediately; breadcrumb state from the crash session must survive the kill.
- SQLite schema migrations use existence guards (`columnExists`/`tableExists`) — never raw `ALTER`/`DROP` without checking first. New tables require both a `Configuration` file and a call in `DataStore.createTables()`.
- `AppConstants.baseUrlSdk` and `baseUrlCms` point to **staging** URLs. Do not change these to production endpoints in source; environment switching is handled outside the SDK.
