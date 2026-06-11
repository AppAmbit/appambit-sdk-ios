# AppAmbit Push Notifications SDK for iOS

Complete push notifications SDK for iOS that integrates seamlessly with the AppAmbit Core SDK ecosystem.

## Features

- **Notification Service Extension base class**: Intercept every notification before display — foreground, background, and killed — using `AppAmbitNotificationService`.
- **App-side listener**: React to notifications in the main app via `setNotificationListener` with `.foreground` and `.opened` states.
- **Zero-Config Setup**: Automatic APNs token capture via method swizzling.
- **Thread-safe**: Compatible with Swift 6 Concurrency.

## Requirements

* iOS 12.0 or newer
* Xcode 15 or newer
* Swift 5.7 or newer

## Install

### Swift Package Manager

* Add the repository URL in Xcode under **File → Add Packages…**
* Select the latest version and attach it to your app target

### CocoaPods

Add this to your Podfile:

```ruby
pod 'AppAmbitPushNotifications'
# or specify version
pod 'AppAmbitPushNotifications', '~> 1.1.0'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like "Unable to find a specification for `AppAmbitPushNotifications`": run `pod repo update`, then `pod install`.)*

---

## The two components

This SDK has two independent pieces that work together:

| Component | Process | When it runs | What it can do |
|---|---|---|---|
| `AppAmbitNotificationService` | Extension (separate) | Before notification is shown — always, regardless of app state | Modify content, download images, process payload |
| `setNotificationListener` | Main app | While app is open (foreground) or when user taps | Update UI, navigate to screens |

They serve different purposes and are not redundant. Use `AppAmbitNotificationService` for processing; use `setNotificationListener` for UI reactions and navigation.

---

## Setup

### 1. Enable Capabilities in Xcode

Select your **app target** → **Signing & Capabilities** → **+ Capability** and add:

- **Push Notifications**

### 2. Configure AppDelegate

For SwiftUI apps, use the provided `AppAmbitAppDelegate` adaptor:

```swift
import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppAmbitAppDelegate.self) var appDelegate

    init() {
        PushNotifications.start()
        AppAmbit.start(appKey: "<YOUR-APPKEY>")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

For UIKit apps, your AppDelegate works automatically — the SDK swizzles the necessary delegate calls.

### 3. Request Permission

```swift
PushNotifications.requestNotificationPermission { granted in
    if granted {
        PushNotifications.setNotificationsEnabled(true)
    }
}
```

---

## Notification Service Extension

`AppAmbitNotificationService` is a base class for `UNNotificationServiceExtension`. It runs in a **separate process** before the notification is displayed, regardless of whether the app is in the foreground, background, or force-killed.

**Requires `mutable-content: 1` in the APNs payload.**

### When to use it

- Process the notification payload as soon as it arrives (analytics, data sync).
- Modify the title, body, or add a media attachment before display.
- Handle notifications reliably regardless of app state.

### Setup

1. In Xcode: **File > New > Target > Notification Service Extension**
2. Add `AppAmbitPushNotifications` to the **extension target** (not just the app target).
3. Embed the extension in your app target: **App target > General > Frameworks, Libraries, and Embedded Content > +** and add the `.appex`.

#### Swift extension — subclass `AppAmbitNotificationService`

`AppAmbitNotificationService` exposes three methods you can override. `didReceive` is
the entry point — the same role as `didReceiveNotificationRequest:` in the Objective-C
example below.

```swift
import AppAmbitPushNotifications
import UserNotifications

final class SampleNotificationService: AppAmbitNotificationService {

    // 1. Entry point — called as soon as the notification arrives.
    //    Always call `super` to keep image-attachment support and the
    //    `handlePayload` hook. Override only if you need to inspect or
    //    rebuild the request before processing.
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        super.didReceive(request, withContentHandler: contentHandler)
    }

    // 2. Mutate the banner before display. Invoked by the base class for every
    //    notification, regardless of app state. Runs in a separate process —
    //    you can change the title, body, or image, but you cannot access your
    //    app's screens.
    override func handlePayload(_ notification: AppAmbitNotification,
                                content: UNMutableNotificationContent) {
        print("Notification arrived: \(notification.title ?? "")")
        content.title = "[\(content.title)]"
    }

    // 3. Called when the ~30 s processing budget is about to expire.
    //    Call `super` to deliver the best attempt content.
    override func serviceExtensionTimeWillExpire() {
        super.serviceExtensionTimeWillExpire()
    }
}
```

#### Objective-C extension — use `AppAmbitNotificationProcessor`

Swift classes shipped from an SPM dynamic library cannot be subclassed from Objective-C
(`objc_subclassing_restricted`). Instead, subclass `UNNotificationServiceExtension`
directly and delegate the work to `AppAmbitNotificationProcessor`:

```objc
#import <UserNotifications/UserNotifications.h>
@import AppAmbitPushNotifications;

@interface NotificationService : UNNotificationServiceExtension
@end

@interface NotificationService ()
@property (nonatomic, copy) void (^contentHandler)(UNNotificationContent *);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;
@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    [AppAmbitNotificationProcessor processRequest:request
                                   contentHandler:contentHandler
                                    handlePayload:^(AppAmbitNotification * _Nonnull notification,
                                                    UNMutableNotificationContent * _Nonnull content) {
        NSLog(@"Notification arrived: %@", notification.title);
        content.title = [content.title stringByAppendingString:@" [Custom]"];
    }];
}

- (void)serviceExtensionTimeWillExpire {
    if (self.bestAttemptContent && self.contentHandler) {
        self.contentHandler(self.bestAttemptContent);
    }
}

@end
```

`AppAmbitNotificationProcessor.process` parses the AppAmbit payload, invokes your
`handlePayload` block (where you can mutate the content), attaches the notification
image asynchronously, and finally calls `contentHandler` to deliver the banner.

---

## App-side Listener (`setNotificationListener`)

Use `setNotificationListener` to react to notifications inside the main app. It fires in two states:

```swift
PushNotifications.setNotificationListener { userInfo, state in
    switch state {
    case .foreground:
        // App was open when the notification arrived.
        // Use this to show an in-app banner or update the UI.
        print("Received in foreground")

    case .opened:
        // User tapped the notification.
        // Use this to navigate to the relevant screen.
        print("User tapped notification")

    @unknown default:
        break
    }
}
```

### Notification States

| State | When it fires | Typical use case |
|---|---|---|
| `.foreground` | App is open when push arrives | Show in-app banner, update UI |
| `.opened` | User taps the notification banner | Navigate to relevant screen |

> Background processing belongs in `AppAmbitNotificationService.handlePayload`, not in this listener.

---

## APNs Payload Reference

### Standard notification

Triggers `AppAmbitNotificationService` before display. Also fires `.foreground` or `.opened` in `setNotificationListener` depending on app state.

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "body": "You have a new update"
    },
    "mutable-content": 1,
    "sound": "default"
  }
}
```

### Payload Fields

| Field | Purpose |
|---|---|
| `aps.alert` | Visible notification content (title and body) |
| `aps.mutable-content` | Triggers `AppAmbitNotificationService` (required for the extension to run) |
| `aps.sound` | Play sound on delivery (`"default"` or custom filename) |
| `aps.badge` | App icon badge number |
| `aps.category` | Action buttons (requires app-side registration) |
| `aps.thread-id` | Notification grouping |

---

## API Reference

### Initialization

```swift
// Minimal
PushNotifications.start()

// With debug logging
PushNotifications.start(debugMode: true)
```

### Permissions

```swift
PushNotifications.requestNotificationPermission { granted in }
PushNotifications.hasNotificationPermission() -> Bool
```

### Enable / Disable

```swift
PushNotifications.setNotificationsEnabled(_ enabled: Bool)
PushNotifications.isNotificationsEnabled() -> Bool
```

### Listener

Swift:

```swift
PushNotifications.setNotificationListener { userInfo, state in
    // state: .foreground | .opened
}
```

Objective-C:

```objc
[PushNotifications setNotificationListener:^(NSDictionary * _Nonnull userInfo,
                                              PushNotificationState state) {
    switch (state) {
        case PushNotificationStateForeground:
            NSLog(@"Foreground: %@", userInfo);
            break;
        case PushNotificationStateOpened:
            NSLog(@"Opened: %@", userInfo);
            break;
    }
}];
```

### Notification Service Extension

Swift subclasses extend `AppAmbitNotificationService` and override `handlePayload`:

```swift
override func handlePayload(_ notification: AppAmbitNotification,
                            content: UNMutableNotificationContent) {
    // Mutate `content` and/or run side effects
}
```

Objective-C extensions call `AppAmbitNotificationProcessor.processRequest:contentHandler:handlePayload:`
from `didReceiveNotificationRequest:withContentHandler:` (see the Notification Service
Extension section above for the full template).

---

## Architecture

```
Push arrives at iOS  (requires mutable-content: 1)
    │
    ├── AppAmbitNotificationService  ← extension process, always runs
    │     → handlePayload: process data, analytics, sync
    │     → didReceive: modify content, download images
    │     → saves to App Groups (if configured)
    │
    └── Main app process
          │
          ├── App open → setNotificationListener(.foreground)
          │
          └── User taps → setNotificationListener(.opened)
```

---

## Differences from Android

| Feature | Android | iOS |
|---|---|---|
| Token type | FCM Token | APNs Device Token |
| Permissions | POST_NOTIFICATIONS (Android 13+) | User Notifications authorization |
| Pre-display processing | N/A | `AppAmbitNotificationService` (`mutable-content: 1`) |
| Notification states | Single callback | `.foreground` / `.opened` |

## Support

For questions or issues, refer to the example application in `Samples/AppAmbit.App.Swift/`.
