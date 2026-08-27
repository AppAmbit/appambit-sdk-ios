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

---

## Quick start

1. Sign up free at [appambit.com](https://appambit.com), no credit card required
2. Create an app in the dashboard and grab your app key
3. Install the SDK ([see below](#install-and-usage))
4. Initialize it at app launch:

**Swift**

```swift
// AppDelegate
import AppAmbit

AppAmbit.start(appKey: "<YOUR-APPKEY>")
```

**Objective-C**

```objective-c
// AppDelegate
@import AppAmbit;

[AppAmbit start:@"<YOUR-APPKEY>"];
```

That's it. Crashes, sessions, and analytics start flowing immediately. Full setup guides live in the [docs](https://docs.appambit.com).

---

## What's inside

### 🚀 Ship
- **Build delivery**: push a build from GitHub, Bitbucket, Azure DevOps, or manually, then send it to team, testers, or clients by email or direct install, and track who installed it
- **Live updates**: ship changes without waiting on an app store review

### 📊 Monitor
- **Crash & error monitoring**: uncaught crashes are captured with full stack traces and threads, then uploaded on the next launch, grouped with who's affected and email alerts on new issues
- **Error logging**: structured log messages with custom properties for quick diagnostics, sent even when the app does not crash
- **Session timeline & breadcrumbs**: automatic screen navigation trail so you see exactly what led to a crash
- **Analytics & event tracking**: automatic session starts, stops, and durations plus structured events with custom properties, live and compared across versions

### 📈 Grow
- **Push notifications**: APNs through the optional `AppAmbitPushNotifications` product, targeted by segment and scheduled from the dashboard
- **Remote config & feature flags**: typed keys (`getString`, `getBoolean`, `getLong`, `getDouble`) with version targeting, so you can flip features, run gradual rollouts, or hit the kill switch without a release
- **CMS**: define content types and entries in the dashboard, then read articles, FAQs, and promos with a fluent query builder that supports filters, full-text search, sorting, and pagination, decoded straight into your own `Decodable` models

### 🗄️ Backend
- **App database**: a managed SQL database with a fluent query builder, batches, and transactions, straight from the SDK or the dashboard
- **Cloud code**: deploy JavaScript functions triggered by HTTP, data events, or manually, then invoke them from the app with typed results, cancellation, and request correlation. Every deploy is a version, so rollback is one click
- **AI agent (MCP)**: build your backend from a conversation with Claude or Cursor ([more below](#built-for-agentic-coding))

### 👥 Teams
- Workspaces, squads, roles and access, per-app reporting

---

## Built for agentic coding

Point Claude or Cursor at the AppAmbit MCP server and it can provision your entire backend from a conversation (content types, database schema, and cloud code functions) while writing the app code that calls them. Paired with a [sample app](#sample-apps) or a [starter app](#starter-apps), that means going from a prompt to a working app with a live backend in a single sitting.

Set it up from the AppAmbit dashboard under **Settings → AI Assistant**, where you create the personal access token and get the connection details for your assistant.

---

## Requirements

* iOS 12.0 or newer
* Xcode 16 or newer
* Swift 6.0 or newer

---

## Getting started

- [Install](#install)
  - [Swift Package Manager](#swift-package-manager)
  - [CocoaPods](#cocoapods)
  - [Push setup](#choose-a-push-setup)
- [Track events](#track-events)
- [Logs](#logs)
- [Breadcrumbs](#breadcrumbs)
- [Remote config](#remote-config)
- [Release distribution](#release-distribution)
- [CMS](#cms)
- [Database](#database)
- [Cloud code](#cloud-code)

### Install

#### Swift Package Manager

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

#### CocoaPods

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

The pod is named `AppAmbitSdk`, but its module is `AppAmbit`, so you always `import AppAmbit`.

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

---

### Usage

Everything below works once `AppAmbit.start(appKey:)` has run. Session activity (starts, stops, and durations) is tracked automatically, and uncaught crashes are captured and uploaded on the next launch with no extra code.


### Track events

Send structured events with custom properties.

**Swift**

```swift
Analytics.trackEvent(eventTitle: "Test TrackEvent", data: ["test1": "test1"])
```

**Objective-C**

```objective-c
[Analytics trackEventWithEventTitle:@"Test TrackEvent"
                               data:@{ @"test1": @"test1" }
                         completion:^(NSError * _Nullable error) {
    if (error) NSLog(@"Error Track Event: %@", error.localizedDescription);
}];
```

---

### Logs

Add structured log messages for debugging, sent even when the app does not crash.

**Swift**

```swift
let properties: [String: String] = ["user_id": "1"]
let message = "Error NullPointerException"
Crashes.logError(message: message, properties: properties, exception: error)
```

**Objective-C**

```objective-c
[Crashes logErrorWithMessage:@"Error ArrayIndex"
                  properties:@{ @"user_id": @"1" }
                    classFqn:NSStringFromClass(self.class)
                  completion:^{
    NSLog(@"Log error sent");
}];

// From an NSException
[Crashes logErrorWithNSException:exception
                      properties:@{ @"user_id": @"1" }
                        classFqn:NSStringFromClass(self.class)
                      completion:^{
    NSLog(@"Log error sent");
}];
```

---

### Breadcrumbs

Screen-change breadcrumbs (push/pop, present/dismiss) are recorded automatically. To display the intended screen name, set a navigation title (`navigationTitle` in SwiftUI, `title` in UIKit and Objective-C). Without a title, the screen appears in the dashboard under the default view or controller name.

**Swift**

```swift
NavigationStack {
  MyView()
    .navigationTitle("MyView")
}
```

**Objective-C**

```objective-c
UIViewController *vc = [UIViewController new];
vc.title = @"MyView";
[self.navigationController pushViewController:vc animated:YES];
```

---

### Remote config

Fetch and apply remote configuration values asynchronously using type-safe methods.

**Swift**

```swift
// Enable remote config
RemoteConfig.enable()

// Get remote config values with type-safe methods
let message = RemoteConfig.getString("data")
let isFeatureEnabled = RemoteConfig.getBoolean("banner")
let discount = RemoteConfig.getLong("discount")
let maxUpload = RemoteConfig.getDouble("max_upload")
```

**Objective-C**

```objective-c
// Enable remote config
[RemoteConfig enable];

// Get remote config values with type-safe methods
NSString *message = [RemoteConfig getString:@"data"];
BOOL isFeatureEnabled = [RemoteConfig getBoolean:@"banner"];
NSInteger discount = [RemoteConfig getLong:@"discount"];
double maxUpload = [RemoteConfig getDouble:@"max_upload"];
```

---

### Release distribution

Ship a build to your team, testers, or clients without waiting on a store review. Connect GitHub, Bitbucket, or Azure DevOps so every pipeline run uploads its artifact. Send it out by email or a direct install link, and see who actually installed it.

This repo ships a pipeline for each one that archives, signs, and exports the IPA, ready to copy into your own app:

| CI | Pipeline |
| --- | --- |
| GitHub Actions | [.github/workflows/build-ipa.yml](.github/workflows/build-ipa.yml) |
| Bitbucket Pipelines | [bitbucket-pipelines.yml](bitbucket-pipelines.yml) |
| Azure DevOps | [azure-devops-pipelines-testapp.yml](azure-devops-pipelines-testapp.yml) |

---

### CMS

Read content you publish from the dashboard (articles, FAQs, promos) without shipping a new build. `Cms.content(_:modelType:)` decodes entries into your own `Decodable` model, and `Cms.content(_:)` returns them untyped.

**Swift**

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

**Objective-C**

```objective-c
CmsQueryObjC *query = [Cms contentWithType:@"blog_extended"];
[query equals:@"is_published" value:@"true"];

[query getListWithCompletion:^(NSArray * _Nonnull items) {
    NSLog(@"%@", items); // each item is an NSDictionary of the entry's fields
}];
```

---

### Database

Query, insert, update, and delete rows in your AppAmbit database with a fluent builder.

**Swift**

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

**Objective-C**

```objective-c
[[[AppAmbitDb from:@"users"] where:@"status" value:@"active"]
  getWithCompletion:^(NSArray<NSDictionary<NSString *, id> *> * _Nullable rows, NSError * _Nullable error) {
    NSLog(@"%@ %@", rows, error);
  }];
```

---

### Cloud code

Invoke authenticated HTTP functions hosted by AppAmbit. Cloud Code uses the same consumer and Bearer token as the rest of the SDK, so no extra setup is needed beyond `AppAmbit.start(appKey:)`. Configure an active Cloud Function with an enabled HTTP trigger and slug in the dashboard, then call it:

**Swift**

```swift
CloudCode.call("hello", body: ["name": "Ada"]) { response, error in
    print(response?.data ?? error ?? "Unknown result")
}
```

**Objective-C**

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

With the dynamic response API, a successful empty body, a `204 No Content` response, and an explicit JSON `null` are all represented as `NSNull()` in `CloudCodeResponse.data`. Typed responses preserve their status and request metadata, and an empty successful body produces `nil` typed data.

See the [Cloud Code mobile guide](https://docs.appambit.com/sdk-guides/cloud-code/) for function setup, HTTP triggers, typed and dynamic responses, errors, request IDs, cancellation, timeouts, and backend examples.

---

## Sample apps

This repo ships two manual-test apps that exercise every public feature, one tab per capability:

| App | Language | Path |
| --- | --- | --- |
| `AppAmbit.App.Swift` | Swift / SwiftUI | [Samples/AppAmbit.App.Swift](Samples/AppAmbit.App.Swift) |
| `AppAmbit.App.ObjC` | Objective-C / UIKit | [Samples/AppAmbit.App.ObjC](Samples/AppAmbit.App.ObjC) |

Replace `<YOUR-APPKEY>` with a real app key before running them. The Cloud Code tab is backed by the deployable handlers in [Samples/CloudCodeExamples.js](Samples/CloudCodeExamples.js).

---

## Starter apps

Skip the blank-project setup. Clone a starter with AppAmbit already wired in: auth, push notifications, analytics, and a CMS-driven feed that needs no rebuild to change content. Each one ships with ready-made content sets you can import directly into your AppAmbit dashboard, then customize to make the app your own.

| Starter | Repo |
| --- | --- |
| .NET MAUI | [organization-app-starter-maui](https://github.com/AppAmbit/organization-app-starter-maui) |
| Flutter | [organization-app-starter-flutter](https://github.com/AppAmbit/organization-app-starter-flutter) |
| React Native | [organization-app-starter-react-native](https://github.com/AppAmbit/organization-app-starter-react-native) |

---

## Other SDKs

Open-source, one per platform. Analytics, crashes, session timeline, CMS, database, and remote config all in the same package.

> One .NET SDK repo, three targets: MAUI, WPF/WinUI, and Avalonia each ship as separate packages from the same source.

| Platform | Repo | Package |
| --- | --- | --- |
| **iOS** *(you are here)* | [appambit-sdk-ios](https://github.com/AppAmbit/appambit-sdk-ios) | [CocoaPods](https://cocoapods.org/pods/appambitsdk) · [Swift Package Manager](https://github.com/AppAmbit/appambit-sdk-ios) |
| Android | [appambit-sdk-android](https://github.com/AppAmbit/appambit-sdk-android) | [Maven Central](https://central.sonatype.com/artifact/com.appambit/appambit) |
| .NET MAUI | [appambit-sdk-dotnet](https://github.com/AppAmbit/appambit-sdk-dotnet) | [NuGet](https://www.nuget.org/packages/com.AppAmbit.Maui) |
| Flutter | [appambit-sdk-flutter](https://github.com/AppAmbit/appambit-sdk-flutter) | [pub.dev](https://pub.dev/packages/appambit_sdk_flutter) |
| React Native | [appambit-sdk-react-native](https://github.com/AppAmbit/appambit-sdk-react-native) | [npm](https://www.npmjs.com/package/@appambit/react-native-sdk) |
| .NET (WPF/WinUI) | [appambit-sdk-dotnet](https://github.com/AppAmbit/appambit-sdk-dotnet) | [NuGet](https://www.nuget.org/packages/com.AppAmbit.Sdk) |
| Avalonia | [appambit-sdk-dotnet](https://github.com/AppAmbit/appambit-sdk-dotnet) | [NuGet](https://www.nuget.org/packages/com.AppAmbit.Avalonia) |

---

## REST API

No SDK? No problem. Every capability (sessions, events, logs, breadcrumbs, consumers, CMS, and the database) is also reachable directly over HTTP, for web apps, backend services, or anything without a native SDK.

📖 [Getting started guide](https://docs.appambit.com/Rest/getting-started/)

---

## Troubleshooting

* **No data in dashboard** → check API key, endpoint, and network access
* **CocoaPods errors** → run `pod repo update`, then `pod install`
* **SPM not resolving** → confirm repo URL and tagged release version
* **Crash not appearing** → crashes are sent on next launch

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
