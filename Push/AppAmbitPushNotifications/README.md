# AppAmbit Push Notifications SDK for iOS

Complete push notifications SDK for iOS that integrates seamlessly with the AppAmbit Core SDK ecosystem. This SDK replicates the Android architecture for consistency across platforms.

## Features

- ✅ **Simple API**: Matches Android SDK for cross-platform consistency
- ✅ **Minimal setup**: Just call `PushNotifications.start()` after AppAmbit initialization
- ✅ **Decoupled architecture**: Internal `PushKernel` handles APNs, public `PushNotifications` facade
- ✅ **Customizable notifications**: Modify notification content before display
- ✅ **Thread-safe**: Compatible with Swift 6 Concurrency
- ✅ **Persistent state**: User preferences stored in UserDefaults

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
pod 'AppAmbitPushNotifications', '~> 0.2.0'
```

Then run:

```bash
pod install
```

Open the generated `.xcworkspace` project.

*(If you get an error like “Unable to find a specification for `AppAmbitPushNotifications`”: run `pod repo update`, then `pod install`.)*

---

## Basic Usage

### 1. Initialize in your App

#### Swift

```swift
import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct MyApp: App {
    init() {
        // First, start AppAmbit Core SDK
        AppAmbit.start(appKey: "<YOUR-APPKEY>") {
            // Then start Push SDK after AppAmbit finishes initialization
            PushNotifications.start()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

#### Objective-C

```objc
#import "AppDelegate.h"
@import AppAmbit;
@import AppAmbitPushNotifications;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [AppAmbit start:@"<YOUR-APPKEY>"];
    [PushNotifications start];
    return YES;
}
```

### 2. Manual Permission Request

#### Swift

```swift
// Request notification permission from the user
PushNotifications.requestNotificationPermission { granted in
    if granted {
        print("Permission granted!")
        // Optionally enable notifications
        PushNotifications.setNotificationsEnabled(true)
    } else {
        print("Permission denied")
    }
}
```

#### Objective-C

```objc
[PushNotifications requestNotificationPermissionWithListener:^(BOOL granted) {
    if (granted) {
        [PushNotifications setNotificationsEnabled:YES];
    } else {
        NSLog(@"Permission denied");
    }
}];
```

### 3. Enable/Disable Notifications

#### Swift

```swift
// Enable notifications (registers for APNs and syncs with backend)
PushNotifications.setNotificationsEnabled(true)

// Enable notifications and wait for APNs + backend sync
PushNotifications.setNotificationsEnabled(true) { success in
    print("Push sync completed: \(success)")
}

// Disable notifications (unregisters from APNs and syncs with backend)
PushNotifications.setNotificationsEnabled(false)

// Check current status
let isEnabled = PushNotifications.isNotificationsEnabled()
```

#### Objective-C

```objc
// Enable notifications
[PushNotifications setNotificationsEnabled:YES];

// Enable notifications and wait for APNs + backend sync
[PushNotifications setNotificationsEnabled:YES completion:^(BOOL success) {
    NSLog(@"Push sync completed: %@", success ? @"YES" : @"NO");
}];

// Disable notifications
[PushNotifications setNotificationsEnabled:NO];

// Check current status
BOOL isEnabled = [PushNotifications isNotificationsEnabled];
```

### 4. Customize Notifications (Optional)

#### Swift

```swift
// Set a customizer to modify notifications before they're displayed
PushNotifications.setNotificationCustomizer { content, notification in
    // Modify the notification content
    content.title = "Custom: \(notification.title ?? "")"
    content.body = "Modified: \(notification.body ?? "")"
    content.badge = 1
    content.sound = .default
    
    // Access custom data
    if let customValue = notification.data["myKey"] {
        print("Custom data: \(customValue)")
    }
}
```

Customization is currently Swift-only; it is not exposed to Objective-C yet.

### 5. Notification Service Extension (Images)

To support image attachments, add a **UNNotificationServiceExtension** and
inherit from `AppAmbitNotificationService`. This handles downloading and attaching
the image URL from the payload.

#### Xcode Steps

1. **File > New > Target > Notification Service Extension**
2. Add the `AppAmbitPushNotifications` package to the **extension target** in Xcode.
3. Use the following class:

```swift
import AppAmbitPushNotifications

final class NotificationService: AppAmbitNotificationService {
    // Override only if you need to inspect custom payload fields.
    override func handlePayload(_ notification: AppAmbitNotification, userInfo: [AnyHashable: Any]) {
        // no-op by default
    }
}
```

> If your app is Objective-C, you can still add this extension in Swift.

#### Required Payload Fields

Your backend must send:
- `mutable-content: 1`
- An image URL key such as `image_url` (also supports `imageUrl` or `image`)

## API Reference

### Starting the SDK

```swift
PushNotifications.start()
```

Must be called after `AppAmbit.start()` completes. The SDK will automatically sync the device token with the backend if notifications are enabled.

### Managing Notifications

#### Swift

```swift
// Enable or disable notifications
PushNotifications.setNotificationsEnabled(_ enabled: Bool)

// Enable or disable notifications and receive sync result
PushNotifications.setNotificationsEnabled(_ enabled: Bool, completion: (@Sendable (Bool) -> Void)?)

// Check if notifications are enabled
PushNotifications.isNotificationsEnabled() -> Bool

// Request system permission
PushNotifications.requestNotificationPermission(listener: ((Bool) -> Void)?)
```

#### Objective-C

```objc
// Enable or disable notifications
[PushNotifications setNotificationsEnabled:(BOOL)enabled];

// Enable or disable notifications and receive sync result
[PushNotifications setNotificationsEnabled:(BOOL)enabled completion:^(BOOL success) {}];

// Check if notifications are enabled
BOOL enabled = [PushNotifications isNotificationsEnabled];

// Request system permission
[PushNotifications requestNotificationPermissionWithListener:^(BOOL granted) {}];
```

### Customization

```swift
// Set a customizer closure
typealias NotificationCustomizer = (UNMutableNotificationContent, AppAmbitNotification) -> Void
PushNotifications.setNotificationCustomizer(_ customizer: NotificationCustomizer?)
```

The customizer is invoked **before** the notification is displayed, allowing you to modify:
- Title
- Body
- Badge
- Sound
- User info / custom data

Use `content` to read or override APNs fields like `sound`, `badge`, `categoryIdentifier`,
`threadIdentifier`, and `interruptionLevel` (iOS 15+). Use `notification.data` for custom payload keys.

## Dashboard Form Fields Support (APNs Mapping)

These fields are provided by your backend (dashboard/console). The SDK reads them from APNs payloads.

**Targeting/Scheduling (Backend only)**
- **Send To**, **Rate Limit**, **Send At**: handled by backend delivery, not by the iOS SDK.

**Content & Behavior (APNs payload)**
- **Title / Body** -> `aps.alert.title` / `aps.alert.body`
- **Sound** -> `aps.sound` (e.g. `"default"` or custom filename)
- **Badge Count** -> `aps.badge`
- **Category** -> `aps.category` (requires app-side `UNNotificationCategory` registration)
- **Thread ID** -> `aps.thread-id`
- **Interruption Level** -> `aps.interruption-level` (iOS 15+)
- **Custom Data Payload** -> any key outside `aps` (available in `AppAmbitNotification.data`)
- **Image URL** -> requires `UNNotificationServiceExtension` and `mutable-content: 1`

## Requirements for Advanced Fields

- **Category**: the app must register matching `UNNotificationCategory` identifiers.
- **Image URL**: the app must add a `UNNotificationServiceExtension` that downloads the image
  and attaches it to the notification. The backend must include `mutable-content: 1` and
  an agreed custom key (e.g. `image_url`) in the payload.
- **Interruption Level**: only applies on iOS 15+.

## Architecture

This SDK follows the same architecture as the Android version:

- **PushNotifications** (public): The facade that exposes all functionality
- **PushKernel** (internal): Decoupled core that handles APNs communication
- **AppAmbitNotification**: Model that encapsulates notification data

The kernel is completely invisible to the end user. All interactions go through `PushNotifications`.

## How It Works

1. **Token Management**: When the app registers for notifications, APNs provides a device token. This token is automatically sent to the AppAmbit backend via `ConsumerService.updateConsumer()`.

2. **State Persistence**: The enabled/disabled state is stored in `UserDefaults`, so it persists across app launches.

3. **Backend Sync**: Every time you call `setNotificationsEnabled()`, the SDK updates the backend with the current token and status.
   When enabling, the backend update happens after APNs returns a token to avoid duplicate updates.

4. **Customization**: Before displaying a foreground notification, the SDK checks if a customizer is set and invokes it, allowing you to modify the content.

## Requirements

- iOS 12.0+
- Swift 6.0+
- AppAmbit Core SDK (must be initialized first)

## Complete Example

### Swift

```swift
import SwiftUI
import AppAmbit
import AppAmbitPushNotifications

@main
struct MyApp: App {
    init() {
        // 1. Start AppAmbit Core
        AppAmbit.start(appKey: "<YOUR-APPKEY>") {
            // 2. Start Push SDK
            PushNotifications.start()
            
            // 3. (Optional) Set up customization
            PushNotifications.setNotificationCustomizer { content, notification in
                content.sound = .default
                content.badge = NSNumber(value: 1)
            }
            
            // 4. Request permission and enable
            PushNotifications.requestNotificationPermission { granted in
                if granted {
                    PushNotifications.setNotificationsEnabled(true)
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Objective-C

```objc
@import AppAmbit;
@import AppAmbitPushNotifications;

- (void)setupPush {
    [AppAmbit start:@"your-key"];
    [PushNotifications start];
    [PushNotifications requestNotificationPermissionWithListener:^(BOOL granted) {
        if (granted) {
            [PushNotifications setNotificationsEnabled:YES];
        }
    }];
}
```

## Differences from Android

While the API is nearly identical, there are platform-specific differences:

| Feature | Android | iOS |
|---------|---------|-----|
| Token type | FCM Token | APNs Device Token |
| Permissions | POST_NOTIFICATIONS (Android 13+) | User Notifications authorization |
| State storage | SharedPreferences | UserDefaults |
| Customization timing | Before display (MessagingService) | Before display (UNUserNotificationCenterDelegate) |

## Support

For questions or issues, refer to the example application in `Samples/AppAmbit.App.Swift/`.
