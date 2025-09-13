# AppAmbit iOS SDK

**Track. Debug. Distribute.**
**AppAmbit: track, debug, and distribute—one SDK, one dashboard.**

The AppAmbit iOS SDK adds lightweight analytics, event tracking, logs, crash reporting, and release distribution hooks to your iOS apps. It is designed for simple setup, low overhead, and production-ready defaults.

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

* iOS 13.0 or newer
* Xcode 15 or newer
* Swift 5.9 or newer

---

## Install

### Swift Package Manager

* Add the repository URL in Xcode under **File → Add Packages…**
* Select the latest version and attach it to your app target

### CocoaPods

* Add `pod 'AppAmbitSdk'` to your `Podfile`
* Run `pod install`
* Open the generated `.xcworkspace`

---

## Quickstart

* Configure the SDK at app launch with your **API key** and **base URL**
* Verify session data flows into your AppAmbit dashboard
* Begin tracking events, logs, and crashes

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
* **Dashboard**: AppAmbit workspace link
* **Examples**: Sample apps (to be published)

---

