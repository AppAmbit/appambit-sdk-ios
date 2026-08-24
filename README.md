<picture>
  <source media="(prefers-color-scheme: light)" srcset="https://assets.appambit.com/logo-light.svg">
  <source media="(prefers-color-scheme: dark)" srcset="https://assets.appambit.com/logo-dark.svg">
  <img alt="AppAmbit logo" src="https://assets.appambit.com/logo-dark.svg" width="280">
</picture>

# AppAmbit iOS SDK

**The App Command Center.**
Everything your app needs after you build it, in one connected platform instead of stitching together separate tools.

[![Discord](https://img.shields.io/discord/1418426396836888617?label=Discord&logo=discord&color=5865F2)](https://discord.gg/nJyetYue2s)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swiftpackageindex.com/AppAmbit/appambit-sdk-ios)
[![CocoaPods](https://img.shields.io/cocoapods/v/AppAmbitSdk.svg)](https://cocoapods.org/pods/AppAmbitSdk)

Analytics, crashes, session timeline, remote config, CMS, database, and cloud code for iOS, one lightweight package, simple setup, minimal overhead.

> Full product docs live here: **[docs.appambit.com](https://docs.appambit.com)**

---

## Contents

* [Quick start](#quick-start)
* [What's inside](#whats-inside)
* [Requirements](#requirements)
* [Install](#install)
* [Usage](#usage)
* [Cloud code](#cloud-code)
* [Sample apps](#sample-apps)
* [Release distribution](#release-distribution)
* [Privacy and data](#privacy-and-data)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [Versioning](#versioning)
* [Security](#security)
* [Starter apps](#starter-apps)
* [Built for agentic coding](#built-for-agentic-coding)

---

## Quick start

1. Sign up free at [appambit.com](https://appambit.com), no credit card required
2. Create an app in the dashboard and grab your app key
3. Install the SDK ([see below](#install))
4. Initialize it at app launch:

### Swift

```swift
// AppDelegate
AppAmbit.start(appKey: "<YOUR-APPKEY>")
```

### Objective-C

```objective-c
// AppDelegate
[AppAmbit startWithAppKey:@"<YOUR-APPKEY>"];
```

That's it. Crashes, sessions, and analytics start flowing immediately.

---

## What's inside

### 🚀 Ship
- **Build delivery**: push a build from GitHub, Bitbucket, Azure DevOps, or manually, then send it to team, testers, or clients and track installs
- **Live updates**: ship changes without waiting on an app store review

### 📊 Monitor
- **Crash & error monitoring**: uncaught crashes are captured with full stack traces and threads, then uploaded on the next launch, grouped with who's affected and email alerts on new issues
- **Error logging**: structured log messages with custom properties for quick diagnostics, sent even when the app does not crash
- **Session timeline & breadcrumbs**: automatic screen navigation trail so you see exactly what led to a crash
- **Analytics & event tracking**: automatic session starts, stops, and durations plus structured events with custom properties, live and compared across versions

### 📈 Grow
- **Push notifications**: APNs through the optional `AppAmbitPushNotifications` product, targeted by segment and scheduled from the dashboard
- **Remote config & feature flags**: typed keys (`getString`, `getBoolean`, `getLong`, `getDouble`) with version targeting, so you can flip features, run gradual rollouts, or hit the kill switch without a release
- **CMS**: read content types and entries with a fluent query builder that supports filters, full-text search, sorting, and pagination, decoded straight into your own `Decodable` models

### 🗄️ Backend
- **App database**: a managed SQL database with a fluent query builder, batches, and transactions, straight from the SDK or the dashboard
- **Cloud code**: invoke authenticated JavaScript functions over HTTP with typed results, cancellation, and request correlation
- **AI agent (MCP)**: build your backend from a conversation with Claude or Cursor ([more below](#built-for-agentic-coding))

### 👥 Teams
- Workspaces, squads, roles and access, per-app reporting


---

## Requirements

* iOS 12.0 or newer
* Xcode 16 or newer
* Swift 6.0 or newer

---

## Install

### Swift Package Manager

> Requires **v1.2.0 or newer**. Earlier tags do not include Cloud Code support.

#### In Xcode

1. Go to **File → Add Package Dependencies…**
2. Paste the repository URL into the search field:

   ```
   https://github.com/AppAmbit/appambit-sdk-ios
   ```

3. Set **Dependency Rule** to **Up to Next Major Version** starting at `v1.2.0`.
4. Click **Add Package**, then attach each product to the target that needs it:

| Product | Add to target | Import |
|---|---|---|
| `AppAmbit` | Your app | `import AppAmbit` |
| `AppAmbitPushNotifications` | Your app *(optional, only if you use push)* | `import AppAmbitPushNotifications` |
| `AppAmbitPushNotificationsExtension` | Your Notification Service Extension *(optional)* | `import AppAmbitPushNotificationsExtension` |

#### Choose a push setup

Add the package repository once, then link products to the target that uses them:

| Setup | Main app target | Notification Service Extension target |
|---|---|---|
| Core SDK only | `AppAmbit` | None |
| Push notifications only | `AppAmbit`, `AppAmbitPushNotifications` | None |
| Push notifications plus NSE | `AppAmbit`, `AppAmbitPushNotifications` | `AppAmbitPushNotificationsExtension` |

Adding the package does not automatically link every product to every target. In
Xcode, select the target and add its product under **General > Frameworks,
Libraries, and Embedded Content**. You can also verify the product under
**Build Phases > Link Binary With Libraries**.

Do not link `AppAmbitPushNotificationsExtension` to the main app, and do not
link `AppAmbitPushNotifications` to the extension. The full push product uses
app-only APIs such as `UIApplication`; the extension product is the
app-extension-safe implementation.

If you only need push notifications, stop after configuring the main app. Create
an NSE only when you need to modify or process a notification before display.

See the [Push Notifications guide](Push/AppAmbitPushNotifications/README.md) for
the complete setup, including SwiftUI, UIKit, CocoaPods, Objective-C, and NSE
troubleshooting.

#### In a `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/AppAmbit/appambit-sdk-ios", from: "1.2.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "AppAmbit", package: "appambit-sdk-ios")
        ]
    )
]
```

### CocoaPods

Add this to your Podfile:

```ruby
pod 'AppAmbitSdk'
# or specify version
pod 'AppAmbitSdk', '~> 1.2.0'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like “Unable to find a specification for `AppAmbitSdk`”: run `pod repo update`, then `pod install`.)*

---

## Usage

* **Session activity**: automatically tracks user session starts, stops, and durations
* **Track events**: send structured events with custom properties
  ### Swift
  ```swift
    Analytics.trackEvent(eventTitle: "Test TrackEvent", data: ["test1":"test1"])
  ```
  ### Objective-C
  ```objetive-c
    [Analytics trackEventWithEventTitle:@"Test TrackEvent" data:@{ @"test1": @"test1" } createdAt:nil completion:nil];
  ```
* **Logs**: add structured log messages for debugging
  ### Swift
  ```swift
    let properties: [String: String] = ["user_id": "1"]
    let message = "Error NullPointerException"
    Crashes.logError(message: message, properties: properties, exception: error)
  ```
  ### Objective-C
  ```objetive-c
    [props setObject:@"123" forKey:@"userId"];
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: exception.reason };
    NSError *error = [NSError errorWithDomain:exception.name code:0 userInfo:userInfo];
    [Crashes logErrorWithMessage:(@"Error ArrayIndex") properties:props classFqn:nil exception:nil fileName:nil lineNumber:0 createdAt:nil completion:nil];
  ```
* **Crash Reporting**: uncaught crashes are automatically captured and uploaded on next launch
* **Breadcrumbs**: automatic screen-change breadcrumbs (push/pop, present/dismiss). To display the intended screen name, set a navigation title (`navigationTitle` in SwiftUI / `title` in UIKit/Objective-C). Without a title, it will appear in the dashboard using the default view/controller name.

  ### Swift

  ```swift
    NavigationStack {
      MyMview()
        .navigationTitle("MyMview")
    }
  ```

  ### Objective-C

  ```objetive-c
    UIViewController *vc = [UIViewController new];
    vc.title = @"MyMview";
    [self.navigationController pushViewController:vc animated:YES];
  ```

* **Remote Config**: fetch and apply remote configuration values asynchronously using type-safe methods (`getString`, `getBoolean`, `getLong`, `getDouble`).

  ### Swift

  ```swift
  // Enable remote config
  RemoteConfig.enable()
  ```

  ```swift
  // Get remote config values with type-safe methods
  let message = RemoteConfig.getString("data")
  let isFeatureEnabled = RemoteConfig.getBoolean("banner")
  let discount = RemoteConfig.getLong("discount")
  let maxUpload = RemoteConfig.getDouble("max_upload")
  ```

  ### Objective-C

  ```objective-c
  // Enable remote config
  [RemoteConfig enable];
  ```

  ```objective-c
  // Get remote config values with type-safe methods
  NSString *message = [RemoteConfig getString:@"data"];
  BOOL isFeatureEnabled = [RemoteConfig getBoolean:@"banner"];
  NSInteger discount = [RemoteConfig getLong:@"discount"];
  double maxUpload = [RemoteConfig getDouble:@"max_upload"];
  ```

* **CMS**: read content you publish from the dashboard (articles, FAQs, promos) without shipping a new build. `Cms.content(_:modelType:)` decodes entries into your own `Decodable` model; `Cms.content(_:)` returns them untyped.

  ### Swift

  ```swift
  Cms.content("blog_extended", modelType: BlogPost.self)
    .equals("is_published", "true")
    .orderByDescending("views_count")
    .getPerPage(20)
    .getList { posts in
      print(posts)
    }
  ```

  Also available: `search`, `notEquals`, `contains`, `startsWith`, `greaterThan(OrEqual)`, `lessThan(OrEqual)`, `inList`, `notInList`, `orderByAscending`, `getPage`.

  ### Objective-C

  ```objective-c
  CmsQueryObjC *query = [Cms contentWithType:@"blog_extended"];
  [query equals:@"is_published" value:@"true"];

  [query getListWithCompletion:^(NSArray * _Nonnull items) {
      NSLog(@"%@", items); // each item is an NSDictionary of the entry's fields
  }];
  ```

* **Database**: query, insert, update and delete rows in your AppAmbit database with a fluent builder.

  ### Swift

  ```swift
  // Query rows
  AppAmbitDb.from("users")
    .where("status", value: "active")
    .orderByDesc("created_at")
    .limit(10)
    .get { rows, error in
      print(rows ?? [], error ?? "")
    }

  // Insert a row
  AppAmbitDb.from("users")
    .insert(["name": "Jane", "status": "active"]) { result, error in
      print(result ?? "", error ?? "")
    }

  // Update requires at least one where()
  AppAmbitDb.from("users")
    .where("id", value: 1)
    .update(["status": "inactive"]) { result, error in
      print(result ?? "", error ?? "")
    }
  ```

  ### Objective-C

  ```objective-c
  [[AppAmbitDb from:@"users"]
    where:@"status" value:@"active"];

  [[[AppAmbitDb from:@"users"] where:@"status" value:@"active"]
    getWithCompletion:^(NSArray<NSDictionary<NSString *, id> *> * _Nullable rows, NSError * _Nullable error) {
      NSLog(@"%@ %@", rows, error);
    }];
  ```

---

## Cloud code

Cloud Code lets your app invoke authenticated HTTP functions hosted by AppAmbit. Initialize the SDK as usual; Cloud Code uses the same consumer and Bearer token as the rest of the SDK.

```swift
AppAmbit.start(appKey: "<YOUR-APPKEY>")
```

After configuring an active Cloud Function with an enabled HTTP trigger and slug in the Dashboard, call it from Swift or Objective-C:

```swift
CloudCode.call("hello", body: ["name": "Ada"]
) { response, error in
    print(response?.data ?? error ?? "Unknown result")
}
```

```objective-c
[CloudCode call:@"hello"
           method:CloudCodeHttpMethodPost
            query:nil
             body:@{ @"name": @"Ada" }
          headers:nil
      completion:^(CloudCodeResponse *response, NSError *error) {
    if (error != nil) {
        NSLog(@"Cloud Code error: %@", error);
        return;
    }
    NSLog(@"%@", response.data);
}];
```

See the complete [Cloud Code mobile guide](https://docs.appambit.com/sdk-guides/cloud-code/) for function setup, HTTP triggers, typed and dynamic responses, errors, request IDs, cancellation, timeouts, and backend examples.

For the dynamic response API, a successful empty body, a `204 No Content` response, and an explicit JSON `null` are represented as `NSNull()` in `CloudCodeResponse.data`. Android exposes the equivalent value as `null`. Typed responses preserve their status and request metadata; an empty successful body produces `nil` typed data.

---

## Sample apps

This repo ships two manual-test apps that exercise every public feature, one tab per capability:

| App | Language | Path |
| --- | --- | --- |
| `AppAmbit.App.Swift` | Swift / SwiftUI | [Samples/AppAmbit.App.Swift](Samples/AppAmbit.App.Swift) |
| `AppAmbit.App.ObjC` | Objective-C / UIKit | [Samples/AppAmbit.App.ObjC](Samples/AppAmbit.App.ObjC) |

Replace `<YOUR-APPKEY>` with a real app key before running them. The Cloud Code tab is backed by the deployable handlers in [Samples/CloudCodeExamples.js](Samples/CloudCodeExamples.js).

---

## Release distribution

* Push the artifact to your AppAmbit dashboard for distribution via email and direct installation.

---

## Privacy and data

* The SDK batches and transmits data efficiently
* You control what is sent, so avoid secrets or sensitive PII
* Supports compliance with Apple platform policies

For details, see the docs: **[docs.appambit.com](https://docs.appambit.com)**

---

## Troubleshooting

* **No data in dashboard** → check API key, endpoint, and network access
* **CocoaPods errors** → run `pod repo update`, then `pod install`
* **SPM not resolving** → confirm repo URL and tagged release version
* **Crash not appearing** → crashes are sent on next launch

---

## Contributing

We welcome issues and pull requests.

* Fork the repo
* Create a feature branch
* Add tests where applicable
* Open a PR with a clear summary

Please follow Swift API design guidelines and document public APIs.

---

## Versioning

Semantic Versioning (`MAJOR.MINOR.PATCH`) is used.

* Breaking changes → **major**
* New features → **minor**
* Fixes → **patch**

---

## Security

If you find a security issue, please contact us at **[hello@appambit.com](mailto:hello@appambit.com)** rather than opening a public issue.

---

## Starter apps

Skip the blank-project setup. Clone a starter with AppAmbit already wired in: auth, push notifications, analytics, and a CMS-driven feed that needs no rebuild to change content. Each one ships with ready-made content sets you can import directly into your AppAmbit dashboard, then customize to make the app your own.

| Starter | Repo |
| --- | --- |
| .NET MAUI | [organization-app-starter-maui](https://github.com/AppAmbit/organization-app-starter-maui) |
| Flutter | [organization-app-starter-flutter](https://github.com/AppAmbit/organization-app-starter-flutter) |
| React Native | [organization-app-starter-react-native](https://github.com/AppAmbit/organization-app-starter-react-native) |

---

## Built for agentic coding

Point Claude or Cursor at the AppAmbit MCP server and it can provision your entire backend from a conversation (content types, database schema, and cloud code functions) while writing the app code that calls them.

Because the agent is driving both sides at once, it wires up the integration as it goes: new CMS field, new database table, new cloud function, and the corresponding app-side code gets built and connected in the same pass instead of as a separate step. Paired with a [starter app](#starter-apps), that means going from a prompt to a working app with a live backend in a single sitting, with scoped, revocable tokens keeping access tight.

---

## Documentation

📚 [docs.appambit.com](https://docs.appambit.com) · 🖥️ [Dashboard](https://appambit.com)

---

## Community

- 💬 [Discord](https://discord.gg/nJyetYue2s)
- ✉️ [hello@appambit.com](mailto:hello@appambit.com)

---

## Pricing

Free plan with all core features, no credit card required. Paid plans start at $5.99/mo with hard spend caps, so there are no overage surprises.

🔗 [appambit.com](https://appambit.com) · [See pricing](https://appambit.com/pricing)

---

## License

Open source under the MIT License. See the [LICENSE](./LICENSE) file for the full terms.
