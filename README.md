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

* Session analytics with automatic lifecycle tracking
* Event tracking with rich properties
* Structured logs with levels and tags
* Crash capture with stack traces and threads
* Network-safe batching, retry, and offline queue
* Configurable endpoints for staging and production
* Small footprint, modern Swift API

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
pod 'AppAmbit'
# or specify version
pod 'AppAmbit', '~> 1.0.0'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like “Unable to find a specification for `AppAmbit`”: run `pod repo update`, then `pod install`.)*

---

## Quickstart

Configure the SDK at app launch with your **API Key**.

### Swift

```swift

// AppDelegate
AppAmbit.start(appKey: "<YOUR-APIKEY>")
```

### Objective-C

```objective-c

// AppDelegate
[AppAmbit startWithAppKey:@"<YOUR-APIKEY>"];
```
---

## Usage

* **Identify Users**: attach traits and metadata to your sessions
* **Track Events**: send structured events with custom properties
* **Logs**: add structured log messages for debugging
* **Crash Reporting**: uncaught crashes are automatically captured

---

## Release Distribution

* Optionally enable in-app build update checks for tester workflows
* Safe to omit for production apps that only use telemetry

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
* **Examples**: Sample swift test app AppAmbitTestApp include in repo. Objective-c test app coming soon. 

---

