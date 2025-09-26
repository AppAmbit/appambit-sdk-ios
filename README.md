# AppAmbit iOS SDK

**Track. Debug. Distribute.**
**AppAmbit: track, debug, and distribute your apps from one dashboard.**

Lightweight SDK for analytics, events, logging, crashes, and offline support. Simple setup, minimal overhead.

> Full product docs live here: **[docs.appambit.com](https://docs.appambit.com)**

---

## Contents

* [Features](#features)
* [Requirements](#requirements)
* [Install](#install)
* [Quickstart](#quickstart)
* [Usage](#usage)
* [Release Distribution](#release-distribution)
* [Privacy and Data](#privacy-and-data)
* [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [Versioning](#versioning)
* [Security](#security)
* [License](#license)

---

## Features

* Session analytics
* Event tracking with rich properties
* Error logging for quick diagnostics 
* Crash capture with stack traces and threads
* Offline support with batching, retry, and queue
* Create mutliple app profiles for staging and production
* Small footprint, modern Swift API with full Objective-C support

---

## Requirements

* iOS 12.0 or newer
* Xcode 15 or newer
* Swift 5.7 or newer

---

## Install

### Swift Package Manager

* Add the repository URL in Xcode under **File → Add Packages…**
* Select the latest version and attach it to your app target

### CocoaPods

Add this to your Podfile:

```ruby
pod 'AppAmbitSdk'
# or specify version
pod 'AppAmbitSdk', '~> 0.0.8'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like “Unable to find a specification for `AppAmbitSdk`”: run `pod repo update`, then `pod install`.)*

---

## Quickstart

Configure the SDK at app launch with your **API Key**.

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
---

## Usage

* **Session Activity**: understand user behavior and engagement
* **Track Events**: send structured events with custom properties
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
* **Crash Reporting**: uncaught crashes are automatically captured

---

## Release Distribution

* Push the artifact to your AppAmbit dashboard for distribution via email and direct installation.

---

## Privacy and Data

* The SDK batches and transmits data efficiently
* You control what is sent — avoid secrets or sensitive PII
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

## License

Open source under the terms described in the [LICENSE](./LICENSE) file.

---

## Links

* **Docs**: [docs.appambit.com](https://docs.appambit.com)
* **Dashboard**: [appambit.com](https://appambit.com)
* **Examples**: Sample swift test app AppAmbitTestApp include in repo. Objective-C test app coming soon. 

---

