# AppAmbit Push Notifications SDK for iOS

Complete push notifications SDK for iOS that integrates seamlessly with the AppAmbit Core SDK ecosystem. This SDK replicates the Android architecture for consistency across platforms.

## Features

- **Simple API**: Matches Android SDK for cross-platform consistency
- **Minimal setup**: Just call `PushNotifications.start()` after AppAmbit initialization
- **Decoupled architecture**: Internal `PushKernel` handles APNs, public `PushNotifications` facade
- **Notification handling**: Receive and customize notifications with typed data
- **Thread-safe**: Compatible with Swift 6 Concurrency
- **Persistent state**: User preferences stored in UserDefaults

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

// Disable notifications (unregisters from APNs and syncs with backend)
PushNotifications.setNotificationsEnabled(false)

// Check current status
let isEnabled = PushNotifications.isNotificationsEnabled()
```

#### Objective-C

```objc
// Enable notifications
[PushNotifications setNotificationsEnabled:YES];

// Disable notifications
[PushNotifications setNotificationsEnabled:NO];

// Check current status
BOOL isEnabled = [PushNotifications isNotificationsEnabled];
```

### 4. Handling Incoming Notifications

Set a handler to receive and optionally customize notifications when they arrive.

#### Swift

```swift
// Professional way to listen and customize notifications
PushNotifications.setNotificationCustomizer { notification in
    let title = notification.request.content.title
    let userInfo = notification.request.content.userInfo
    
    print("Received: \(title)")
    
    // Access custom data payload
    if let customData = userInfo["myCustomKey"] as? String {
        print("Custom data: \(customData)")
    }
}
```

For **foreground notifications** (app open), the SDK automatically handles them if swizzling is enabled. You can intercept them using `setNotificationCustomizer`.

For **background notifications** (app closed), override in your `NotificationService`:

```swift
class NotificationService: AppAmbitNotificationService {
    override func handlePayload(_ notification: AppAmbitNotification, userInfo: [AnyHashable: Any]) {
        // Process background notification
        print("Background: \(notification.title ?? "")")
    }
}
```

#### Objective-C

```objc
// Closure-based listener is Swift-only
// Use Objective-C bridge methods if available
```

### 5. Notification Service Extension (Advanced Processing)

For advanced features like image attachments or processing notifications when your app is not running, add a **UNNotificationServiceExtension** and inherit from `AppAmbitNotificationService`. This allows you to modify or enrich notifications before they are displayed to the user.

#### Xcode Steps

1. **File > New > Target > Notification Service Extension**
2. Add the `AppAmbitPushNotifications` package to the **extension target** in Xcode.
3. Use the following class:

```swift
import AppAmbitPushNotifications

final class NotificationService: AppAmbitNotificationService {
    // Override to customize or process notifications
    override func handlePayload(_ notification: AppAmbitNotification, userInfo: [AnyHashable: Any]) {
        // Access notification data
        print("Processing: \(notification.title ?? "")")
    }
}
```

> If your app is Objective-C, you can still add this extension in Swift.

#### When to Use
- To attach images (requires `mutable-content: 1` in payload).
- To process or modify notifications before display, even when the app is closed or in the background.
- For custom logic like analytics or data handling on notification arrival.

#### Required Payload Fields
Your backend must include `mutable-content: 1` for the extension to run. For images, add an image URL key like `image_url`.

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

```swift
// Professional way to listen for both local and remote notifications
PushNotifications.setNotificationCustomizer(_ listener: ((UNNotification) -> Void)?)
```

The customizer receives the raw `UNNotification` object. For background processing (when the app is not active), use a Notification Service Extension.

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
- **Image URL**: the app must add a `UNNotificationServiceExtension` that downloads the image and attaches it to the notification. The backend must include `mutable-content: 1` and an agreed custom key (e.g. `image_url`) in the payload.
- **Interruption Level**: only applies on iOS 15+.
- **Background Processing**: For any custom processing when the app is not active, add a `UNNotificationServiceExtension` inheriting from `AppAmbitNotificationService`.

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

4. **Notification Handling**: When a notification arrives, the SDK invokes the set handler (if any), allowing you to process typed data and optionally customize the notification before display. For background processing (when the app is not active), use a Notification Service Extension.

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
            
            // 3. (Optional) Set up notification handler
            class MyHandler: PushNotifications.NotificationHandler {
                func handleNotification(_ notification: AppAmbitNotification, content: UNMutableNotificationContent) {
                    print("Received: \(notification.title ?? "")")
                    content.badge = 1
                }
            }
            PushNotifications.setNotificationHandler(MyHandler())
            
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

// In your AppDelegate or SceneDelegate, add the delegate:
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        PushNotifications.handleNotificationInForeground(userInfo: notification.request.content.userInfo)
        completionHandler([.alert, .sound])
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
| Notification handling | MessagingService (background) | UNUserNotificationCenterDelegate (foreground) + NotificationServiceExtension (background) |

## Support

For questions or issues, refer to the example application in `Samples/AppAmbit.App.Swift/`. If you need to process notifications when your app is not running (e.g., for images or custom logic), check the Notification Service Extension section.
