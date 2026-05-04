# AppAmbit Push Notifications SDK for iOS

Complete push notifications SDK for iOS that integrates seamlessly with the AppAmbit Core SDK ecosystem. This SDK replicates the Android architecture for consistency across platforms.

## Features

- **Unified Listener**: Single entry point to handle foreground, tap, and background notifications
- **State-aware Callbacks**: Know exactly how the notification was received (`.foreground`, `.opened`, `.background`)
- **Notification Customization**: Modify notifications before display using `NotificationServiceExtension`
- **Zero-Config Setup**: Automatic APNs token capture via method swizzling
- **Thread-safe**: Compatible with Swift 6 Concurrency

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
pod 'AppAmbitPushNotifications', '~> 0.5.0'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like "Unable to find a specification for `AppAmbitPushNotifications`": run `pod repo update`, then `pod install`.)*

---

## Setup

### 1. Enable Capabilities in Xcode

Before writing any code, you must enable the required capabilities in your Xcode project:

1. Select your **app target** in Xcode.
2. Go to **Signing & Capabilities**.
3. Click **+ Capability** and add:
   - **Push Notifications**
   - **Background Modes** → enable:
     - ✅ **Background fetch**
     - ✅ **Remote notifications**

> Without these capabilities, iOS will not deliver notifications to your app in the background.

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

For UIKit apps, your AppDelegate works automatically — the SDK uses method swizzling to intercept the necessary delegate calls.

### 3. Request Permission

```swift
PushNotifications.requestNotificationPermission { granted in
    if granted {
        PushNotifications.setNotificationsEnabled(true)
    }
}
```

---

## Receiving Notifications

### Unified Notification Listener

Use `setNotificationListener` to handle all incoming notifications. The callback provides two parameters:
- `userInfo`: the notification payload.
- `state`: a `PushNotificationState` enum indicating how the notification was received.

`setNotificationListener` is the default app-side integration and should be your primary entry point for notification handling.
You can use it on its own (no extension required) for foreground, opened, and background app events.

```swift
PushNotifications.setNotificationListener { userInfo, state in
    switch state {
    case .foreground:
        // The app was open when the notification arrived.
        // Use this to update UI or show an in-app alert.
        print("Received in foreground")
        
    case .opened:
        // The user tapped the notification banner to open the app.
        // Use this to navigate to the relevant screen.
        print("User opened notification")
        
    case .background:
        // The app was woken up in the background.
        // Use this to sync data or update local storage.
        print("Received in background")
        
    @unknown default:
        break
    }
}
```

### Notification States

| State | When it fires | Typical use case |
|---|---|---|
| `.foreground` | App is open and visible | Update UI, show in-app banner |
| `.opened` | User tapped the notification | Navigate to relevant content |
| `.background` | App was woken in background | Sync data, update local cache |

> **Note**: The `.background` state requires the APNs payload to include `content-available: 1`. Without this field, iOS will not wake your app in the background.

### Execution Order (What Runs First)

When a push arrives, execution depends on payload and app state:

1. If `mutable-content: 1` is present, `AppAmbitNotificationService` runs first in the extension process to modify content before display.
2. App callbacks run in the app process when applicable:
  - `.foreground` via `willPresent` when app is open.
  - `.background` via `didReceiveRemoteNotification` when iOS wakes the app (`content-available: 1`).
  - `.opened` via notification tap.
3. `setNotificationListener` receives the final app-side state callback.

In short: extension-first for content customization, listener for app behavior.

---

## Customizing Notifications (Notification Service Extension)

To modify a notification's appearance before it is displayed (e.g., add images, change title, decrypt content), use a **Notification Service Extension**.

This extension complements `setNotificationListener`; it does not replace it.

### When to Use

- Attach images or media to the notification.
- Modify the title or body dynamically.
- Group notifications by thread or conversation.
- Set custom interruption levels (iOS 15+).

### Setup

1. In Xcode: **File > New > Target > Notification Service Extension**
2. Add the `AppAmbitPushNotifications` package to the **extension target**.
3. Implement your service:

```swift
import AppAmbitPushNotifications

final class NotificationService: AppAmbitNotificationService {
    
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        
        // Modify the notification before display
        let data = content.userInfo["data"] as? [String: Any] ?? [:]
        
        if let customTitle = data["custom_title"] as? String {
            content.title = customTitle
        }
        
        let newRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: request.trigger
        )
        
        // Delegate to parent for image download and final delivery
        super.didReceive(newRequest, withContentHandler: contentHandler)
    }
}
```

> **Important**: The APNs payload must include `mutable-content: 1` for the extension to be invoked by iOS.

---

## APNs Payload Reference

### Standard Notification

Shows a banner and triggers `.foreground` or `.opened` states:

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "body": "You have a new update"
    },
    "sound": "default",
    "badge": 1
  }
}
```

### Notification with Background Wake

Shows a banner **and** wakes the app in the background (`.background` state):

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "body": "You have a new update"
    },
    "content-available": 1
  }
}
```

### Full-Featured Notification

Shows a banner, wakes the app, **and** triggers the Notification Service Extension for customization:

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "subtitle": "From John",
      "body": "Hey, check this out!"
    },
    "content-available": 1,
    "mutable-content": 1,
    "sound": "default",
    "badge": 3
  },
  "data": {
    "image_url": "https://example.com/photo.jpg",
    "deep_link": "/chat/123"
  }
}
```

### Payload Fields Summary

| Field | Required | Purpose |
|---|---|---|
| `aps.alert` | Yes | Visible notification content (title, body, subtitle) |
| `aps.content-available` | For `.background` state | Wakes the app to run code in background |
| `aps.mutable-content` | For customization | Triggers NotificationServiceExtension |
| `aps.sound` | No | Play sound on delivery (`"default"` or custom) |
| `aps.badge` | No | App icon badge number |
| `aps.category` | No | Action buttons (requires app-side registration) |
| `aps.thread-id` | No | Notification grouping |

---

## API Reference

### Initialization

```swift
// Start the Push SDK (call before AppAmbit.start)
PushNotifications.start(debugMode: false, autoRequestPermissions: false)
```

### Permissions

```swift
// Request system permission
PushNotifications.requestNotificationPermission { granted in }

// Check if permission was granted
PushNotifications.hasNotificationPermission() -> Bool
```

### Enable / Disable

```swift
// Enable or disable notifications
PushNotifications.setNotificationsEnabled(_ enabled: Bool)

// Check current state
PushNotifications.isNotificationsEnabled() -> Bool
```

### Listeners

```swift
// Unified notification listener (default and recommended)
PushNotifications.setNotificationListener { userInfo, state in
    // state: .foreground | .opened | .background
}

// Background-only listener with completion handler (optional, advanced)
PushNotifications.setBackgroundNotificationListener { userInfo, completionHandler in
    // Process data...
    completionHandler(.newData)
}
```

---

## Architecture

```
Push arrives at iOS
    │
    ├── NotificationServiceExtension (separate process)
    │     → Runs BEFORE display (requires mutable-content: 1)
    │     → Modify title, body, add images
    │     → Runs even if app is force-quit
    │
    ├── didReceiveRemoteNotification (app process)
    │     → Runs when app is woken in background
    │     → Triggers .background state
    │     → Requires content-available: 1
    │
    ├── willPresent (app process, foreground only)
    │     → Triggers .foreground state
    │
    └── didReceive (app process, user interaction)
          → Triggers .opened state
```

All paths converge into a single `setNotificationListener` callback.

If both are configured, `AppAmbitNotificationService` handles pre-display customization first, then app-side events are delivered to `setNotificationListener` when the app process is involved.

---

## Differences from Android

| Feature | Android | iOS |
|---------|---------|-----|
| Token type | FCM Token | APNs Device Token |
| Permissions | POST_NOTIFICATIONS (Android 13+) | User Notifications authorization |
| Background wake | Always (via `onMessageReceived`) | Requires `content-available: 1` |
| Pre-display modification | N/A | NotificationServiceExtension (`mutable-content: 1`) |
| Notification states | Single callback | `.foreground` / `.opened` / `.background` |

## Support

For questions or issues, refer to the example application in `Samples/AppAmbit.App.Swift/`.
