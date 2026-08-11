<p align="center">
  <strong>AppAmbit Push Notifications for iOS</strong><br>
  Push delivery, app-side events, and optional Notification Service Extension processing.
</p>

This README is organized as a guided setup. Choose **one** installation method,
then decide whether your app needs an NSE.

## Contents

1. [Quick start](#quick-start)
2. [Install the SDK](#1-install-the-sdk)
   - [Swift Package Manager](#option-1-swift-package-manager)
   - [CocoaPods](#option-2-cocoapods)
3. [Configure the main app](#2-configure-the-main-app)
4. [Listen inside the app](#3-listen-inside-the-app)
5. [Add an NSE](#4-add-a-notification-service-extension-optional)
6. [Troubleshooting](#troubleshooting)

## Quick start

### Choose what you need

| Goal | What to install | Where to continue |
|---|---|---|
| Push notifications only | Core SDK plus the main push product | Stop after section 3 |
| Push notifications plus pre-display processing | Core SDK, main push product, and NSE product/pod | Continue to section 4 |

### Choose one installation method

- **Swift Package Manager**: follow [Option 1](#option-1-swift-package-manager).
- **CocoaPods**: follow [Option 2](#option-2-cocoapods).

> **Important:** Do not install SPM and CocoaPods in the same target.

If you only use the AppAmbit core SDK, you do not need this push package or an
NSE. The `Undefined symbol` error described later applies only to the SPM NSE
product when it is not linked to the NSE target.

## Requirements

- iOS 12.0 or newer
- Xcode 16 or newer
- Swift 6.0 or newer
- AppAmbit SDK `1.1.2` or newer

The `1.1.2` release keeps the main push product and the NSE product separate.

## 1. Install the SDK

### Option 1: Swift Package Manager

#### Push notifications in the main app

Use this path when you need permission, APNs registration, foreground
notifications, or notification tap events. You do **not** need an NSE.

1. In Xcode, select **File > Add Package Dependencies...**.
2. Enter:

   ```text
   https://github.com/AppAmbit/appambit-sdk-ios
   ```

3. Select **Up to Next Major Version** starting at `1.1.2`.
4. Add the package to the project.
5. When Xcode asks which products belong to the **main app target**, select:

   - `AppAmbit`
   - `AppAmbitPushNotifications`

> **Push only:** Do not create an NSE and do not add
> `AppAmbitPushNotificationsExtension`. Continue with [section 2](#2-configure-the-main-app).

#### If the app will also use an NSE

Complete the same main app setup above. Do not add the extension product yet.
Add it in [section 4](#4-add-a-notification-service-extension-optional), after
the NSE target exists.

### Option 2: CocoaPods

Use this option instead of SPM. Do not add the SDK through **Package
Dependencies** when using CocoaPods.

#### Push notifications in the main app

Add the pods to the **main app target** in your `Podfile`:

```ruby
target 'MyApp' do
  pod 'AppAmbitSdk', '~> 1.1.2'
  pod 'AppAmbitPushNotifications', '~> 1.1.2'
end
```

Run:

```bash
pod install
```

Open the generated `.xcworkspace`, not the `.xcodeproj`. Continue with [section
2](#2-configure-the-main-app).

#### If the app will also use an NSE

Keep the main app block above. Add the extension pod in [section
4](#4-add-a-notification-service-extension-optional), after the NSE target
exists.

## 2. Configure the main app

Complete this section after choosing SPM or CocoaPods. The app code is the same
for both installation methods.

### 2.1 Enable the capability

1. Select the **main app target**.
2. Open **Signing & Capabilities**.
3. Add **Push Notifications**.

### 2.2 Initialize the SDK

#### SwiftUI

Use `AppAmbitAppDelegate` so the push SDK can receive the APNs token:

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

#### UIKit

Keep your existing app delegate and start both SDKs during app launch:

```swift
import UIKit
import AppAmbit
import AppAmbitPushNotifications

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    PushNotifications.start()
    AppAmbit.start(appKey: "<YOUR-APPKEY>")
    return true
}
```

The push SDK observes APNs registration callbacks. You do not need to replace
your existing `AppDelegate` methods.

<details>
<summary>Objective-C app setup</summary>

```objc
#import "AppDelegate.h"
@import AppAmbit;
@import AppAmbitPushNotifications;

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [AppAmbit start:@"<YOUR-APPKEY>"];
    [PushNotifications start];
    return YES;
}

@end
```

</details>

### 2.3 Ask for permission

Ask for permission when your app is ready to show the system prompt:

```swift
PushNotifications.requestNotificationPermission { granted in
    guard granted else { return }
    PushNotifications.setNotificationsEnabled(true)
}
```

<details>
<summary>Objective-C permission request</summary>

```objc
[PushNotifications requestNotificationPermissionWithListener:^(BOOL granted) {
    if (granted) {
        [PushNotifications setNotificationsEnabled:YES];
    }
}];
```

</details>

`setNotificationsEnabled(true)` registers the app for remote notifications and
synchronizes the enabled state with AppAmbit.

## 3. Listen inside the app

Use this listener for events that happen in the **main app process**:

```swift
PushNotifications.setNotificationListener { userInfo, state in
    switch state {
    case .foreground:
        // The app was open when the notification arrived.
        print("Received notification: \(userInfo)")

    case .opened:
        // The user tapped the notification.
        print("Opened notification: \(userInfo)")

    @unknown default:
        break
    }
}
```

| State | When it fires | Typical use |
|---|---|---|
| `.foreground` | The app is open when the notification arrives | Show an in-app banner or update the UI |
| `.opened` | The user taps the notification | Navigate to the relevant screen |

<details>
<summary>Objective-C notification listener</summary>

```objc
[PushNotifications setNotificationListener:^(NSDictionary *userInfo,
                                              PushNotificationState state) {
    switch (state) {
        case PushNotificationStateForeground:
            NSLog(@"[Foreground] Notification received while app is open: %@", userInfo);
            break;
        case PushNotificationStateOpened:
            NSLog(@"[Opened] User tapped the notification: %@", userInfo);
            break;
    }
}];
```

</details>

> **Stop here if you only need app-side push behavior.** Do not create an NSE.

## 4. Add a Notification Service Extension (optional)

Create an NSE only when you need to modify a notification before display,
download an image, or process a payload while the app is not running.

An NSE runs in a separate process. It cannot access your app's screens,
navigation, or `UIApplication`.

### 4.1 Create the NSE target

1. In Xcode, select **File > New > Target...**.
2. Choose **Notification Service Extension**.
3. Give the target a name, for example `NotificationServiceExtension`.
4. Keep the generated `NotificationService.swift` file in that target.

### 4.2 Add the dependency to the NSE target

Add the dependency only after the NSE target exists.

#### If you chose Swift Package Manager

1. Select the new `NotificationServiceExtension` target.
2. Open **General > Frameworks, Libraries, and Embedded Content**.
3. Click **+** and add `AppAmbitPushNotificationsExtension`.
4. Open **Build Phases > Link Binary With Libraries**.
5. Confirm that `AppAmbitPushNotificationsExtension` is listed there.

> **Important:** This is the extension product. Do not add
> `AppAmbitPushNotifications` to the NSE. That product uses app-only APIs such
> as `UIApplication`.

> **SPM linker error:** If the NSE imports the module but this product is not
> linked to the NSE target, Xcode can show `Undefined symbol` errors for
> `AppAmbitNotificationService` or `AppAmbitNotification.title`. The main app
> can still build normally because this problem belongs only to the separate
> NSE target.

#### If you chose CocoaPods

Add this block to the same `Podfile`:

```ruby
target 'NotificationServiceExtension' do
  pod 'AppAmbitPushNotificationsExtension', '~> 1.1.2'
end
```

The extension pod belongs inside the extension target block. It must not be
inside the main app target block.

Run CocoaPods again:

```bash
pod install
```

Open the generated `.xcworkspace`, not the `.xcodeproj`.

### 4.3 Verify that the NSE is embedded

Xcode normally embeds the new `.appex` automatically. Verify it under:

**Main app target > Build Phases > Embed App Extensions**

Add the extension there only if it is missing.

### 4.4 Implement the Swift NSE

Use the extension module in `NotificationService.swift`:

```swift
import UserNotifications
import AppAmbitPushNotificationsExtension
```

> Choose **one** of the following Swift examples. Do not paste both classes into
> the same `NotificationService.swift` file.

#### Simple example: customize the content

Use this version when you only need to change the title, body, badge, or another
field before the notification is displayed. This is the recommended starting
point.

```swift
final class NotificationService: AppAmbitNotificationService {
    override func handlePayload(
        _ notification: AppAmbitNotification,
        content: UNMutableNotificationContent
    ) {
        content.title = "[AppAmbit] \(content.title)"
    }
}
```

The base class keeps the notification lifecycle, image attachments, and final
`contentHandler` call. In most projects, `handlePayload` is the only method you
need to override.

#### Complete example: use all three lifecycle methods

Use this version when you need to inspect or rebuild the request, customize the
parsed payload, and handle the extension timeout explicitly.

```swift
import Foundation
import UserNotifications
import AppAmbitPushNotificationsExtension

final class SampleNotificationService: AppAmbitNotificationService {

    // Entry point. Use this when the original request must be inspected or
    // rebuilt before the AppAmbit base class processes it.
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }

        let dataPayload = bestAttemptContent.userInfo["data"]
            as? [AnyHashable: Any] ?? bestAttemptContent.userInfo

        bestAttemptContent.title += " Custom"

        if let category = dataPayload["category_type"] as? String {
            bestAttemptContent.categoryIdentifier = category
        }

        if let threadId = dataPayload["chat_id"] as? String {
            bestAttemptContent.threadIdentifier = threadId
        }

        let updatedRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: bestAttemptContent,
            trigger: request.trigger
        )

        super.didReceive(updatedRequest, withContentHandler: contentHandler)
    }

    // Main customization hook. It receives the parsed AppAmbit notification
    // and the mutable content that will be displayed.
    override func handlePayload(
        _ notification: AppAmbitNotification,
        content: UNMutableNotificationContent
    ) {
        NSLog("Notification title: %@, body: %@",
              notification.title ?? "",
              notification.body ?? "")
    }

    // Fallback when iOS is about to stop the extension, normally after about
    // 30 seconds. Always call super to deliver the best available content.
    override func serviceExtensionTimeWillExpire() {
        super.serviceExtensionTimeWillExpire()
    }
}
```

The three methods have different jobs:

- `didReceive`: first entry point; use it only when the original request needs custom processing before calling `super`.
- `handlePayload`: normal customization hook; use it to change the notification content or inspect `AppAmbitNotification`.
- `serviceExtensionTimeWillExpire`: last chance to deliver content before iOS stops the extension.

The parsed notification exposes:

```swift
notification.title
notification.body
notification.imageUrl
notification.data
```

### 4.5 Implement the Objective-C NSE

Objective-C uses `AppAmbitNotificationProcessor` instead of subclassing the
Swift `AppAmbitNotificationService`. The processor manages the equivalent
notification lifecycle for an Objective-C NSE.

Objective-C extensions should subclass `UNNotificationServiceExtension` and use
`AppAmbitNotificationProcessor`:

```objc
#import <UserNotifications/UserNotifications.h>
@import AppAmbitPushNotificationsExtension;

@interface NotificationService : UNNotificationServiceExtension
@property (nonatomic, copy) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;
@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                    withContentHandler:(void (^)(UNNotificationContent *contentToDeliver))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    [AppAmbitNotificationProcessor processRequest:request
                                    contentHandler:contentHandler
                                     handlePayload:^(AppAmbitNotification *notification,
                                                     UNMutableNotificationContent *content) {
        content.title = [content.title stringByAppendingString:@" [AppAmbit]"];
    }];
}

- (void)serviceExtensionTimeWillExpire {
    if (self.bestAttemptContent && self.contentHandler) {
        self.contentHandler(self.bestAttemptContent);
    }
}

@end
```

Do not import `AppAmbitPushNotifications` in the NSE. Use
`AppAmbitPushNotificationsExtension`.

### 4.6 Send a payload that the NSE can process

The payload must contain `mutable-content: 1` inside `aps` for the NSE to run:

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "body": "You have a new update"
    },
    "mutable-content": 1,
    "sound": "default"
  },
  "image": "https://example.com/image.jpg"
}
```

The `image` field is optional. When present, the NSE downloads it and attaches
it to the notification.

## Target assignment

The final setup is always:

```text
Main app target:
  AppAmbit
  AppAmbitPushNotifications

Notification Service Extension target:
  AppAmbitPushNotificationsExtension
```

| Installation method | Main app | NSE |
|---|---|---|
| Swift Package Manager | Products selected for the app target | Extension product added in section 4.2 |
| CocoaPods | Pods inside the app target block | Extension pod inside the NSE target block |

## Troubleshooting

### SPM + NSE: `Undefined symbol` linker errors

These errors mean that `NotificationService.swift` can see the extension module,
but the extension product is not linked to the NSE target:

```text
Undefined symbol: direct field offset for AppAmbitPushNotificationsExtension.AppAmbitNotification.title
Undefined symbol: method descriptor for AppAmbitPushNotificationsExtension.AppAmbitNotificationService.handlePayload(...)
Undefined symbol: type metadata for AppAmbitPushNotificationsExtension.AppAmbitNotificationService
Undefined symbol: _OBJC_METACLASS_$__TtC...AppAmbitNotificationService
Linker command failed with exit code 1
```

This is an **NSE target configuration problem**, not a failure of the core
`AppAmbit` or `AppAmbitSdk` integration. The main app can build normally while
the separate NSE target is missing its library.

#### Fix for Swift Package Manager

1. Select the `NotificationServiceExtension` target.
2. Open **General > Frameworks, Libraries, and Embedded Content**.
3. Add `AppAmbitPushNotificationsExtension`.
4. Open **Build Phases > Link Binary With Libraries**.
5. Confirm that `AppAmbitPushNotificationsExtension` is listed there.

The main app uses `AppAmbit` and `AppAmbitPushNotifications`. The NSE uses only
`AppAmbitPushNotificationsExtension`.

#### Fix for CocoaPods

Make sure the extension pod is inside the extension target block, then run
`pod install` and open the generated `.xcworkspace`:

```ruby
target 'NotificationServiceExtension' do
  pod 'AppAmbitPushNotificationsExtension', '~> 1.1.2'
end
```

### `UIApplication is unavailable in application extensions`

The main push product was added to the NSE. Remove it and use only
`AppAmbitPushNotificationsExtension` in the NSE.

### The NSE does not run

Check all of the following:

- The payload contains `aps.mutable-content = 1`.
- The notification contains an `aps.alert` payload.
- The `.appex` is embedded under the main app target.
- The NSE uses the extension product or pod, not the main push product.

### CocoaPods changes do not appear in Xcode

Open the generated `.xcworkspace` after `pod install`. Do not open the original
`.xcodeproj`.

For platform setup and notification delivery configuration, see the [AppAmbit
documentation](https://docs.appambit.com).
