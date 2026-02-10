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
* Ambit Trail records detailed navigation for debugging
* Event tracking with custom properties
* Remote Config – dynamic configuration values fetched and applied at runtime
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
pod 'AppAmbitSdk', '~> 0.1.2'
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

* **Session activity** – automatically tracks user session starts, stops, and durations
* **Ambit Trail** – records detailed navigation of user and system actions leading up to an issue for easier debugging
* **Track events** – send structured events with custom properties
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

* **Remote Config**: fetch and apply remote configuration values asynchronously using type-safe methods (`getString`, `getBoolean`, `getInt`, `getDouble`).

  ### Swift

  ```swift
  // 1. Set default values (Optional, but recommended to avoid nulls before fetch)
  RemoteConfig.setDefaults(fromPlist: "default_values")
  ```
  ```swift
  // 2. Fetch and apply
  RemoteConfig.fetchAndActivate { success in
      if success {
          print("Remote Config fetched and activated successfully")
      } else {
          print("Failed to fetch Remote Config")
      }
  }
  ```
  ```swift
  // 3. Get values (using the correct type method)
  let messageValue = RemoteConfig.getString("data")
  let isBannerVisible = RemoteConfig.getBoolean("banner")
  let discountValue = RemoteConfig.getInt("discount")
  let maxUploadSize = RemoteConfig.getDouble("max_upload")
  ```

  ### Objective-C

  ```objective-c
  // 1. Set default values (Optional, but recommended to avoid nulls before fetch)
  [RemoteConfig setDefaultsFromPlist:@"default_values"];
  ```

  ```objective-c
  // 2. Fetch and apply
  [RemoteConfig fetchAndActivateWithCompletion:^(BOOL success) {
      if (success) {
          NSLog(@"Remote Config fetched and activated successfully");
      } else {
          NSLog(@"Failed to fetch Remote Config");
      }
  }];
  ```
  
  ```objective-c
  // 3. Get values (using the correct type method)
  NSString *messageValue = [RemoteConfig getString:@"data"];
  BOOL isBannerVisible = [RemoteConfig getBoolean:@"banner"];
  NSInteger discountValue = [RemoteConfig getInt:@"discount"];
  double maxUploadSize = [RemoteConfig getDouble:@"max_upload"];
  ```

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
* **Discord**: [discord.gg](https://discord.gg/nJyetYue2s)
* **Examples**: Sample Swift test app `AppAmbit.App.Swift` and Objective-C test app `AppAmbit.App.ObjC` are included in this repo. 

---
