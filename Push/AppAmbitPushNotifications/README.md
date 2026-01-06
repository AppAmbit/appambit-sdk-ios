# AppAmbit Push Notifications SDK

Complete push notifications SDK for iOS that integrates with the AppAmbit ecosystem.

## Features

- ✅ **Minimal configuration**: No manual setup required!
- ✅ **Simple API**: `PushNotifications.start()` to begin
- ✅ **Listener pattern**: Delegate to handle events
- ✅ **Auto debug**: Token visible in debug mode
- ✅ **Thread-safe**: Compatible with Swift 6 Concurrency
- ✅ **Auto-configuration**: Automatically detects bundle ID and handles delegates

## Quick Installation

### Swift Package Manager

```swift
dependencies: [
    .package(path: "../AppAmbitPushNotifications")
]
```

### Minimal Code

```swift
import AppAmbitPushNotifications

// In your App or AppDelegate - No configuration needed!
PushNotifications.start(debugMode: true)  // For development
// PushNotifications.start(debugMode: false) // For production
```

That's it! The SDK automatically detects your bundle ID.

## Basic Usage

```swift
import AppAmbitPushNotifications

class PushManager: PushNotificationsDelegate {
    
    func initialize() {
        // No bundle ID needed! Automatically detected
        PushNotifications.start(debugMode: true)
        PushNotifications.addDelegate(self)
    }
    
    // Receive device token
    func pushNotifications(_ pushNotifications: PushNotifications, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: String) {
        print("Token: \(deviceToken)")
    }
    
    // Handle received notifications
    func pushNotifications(_ pushNotifications: PushNotifications, didReceiveRemoteNotification userInfo: [String: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("Notification: \(userInfo)")
        completionHandler(.newData)
    }
}
```

## API Reference

### Configuration

```swift
// Development (sandbox + detailed logs) - Default
PushNotifications.start()  // debugMode: true by default

// Explicit development
PushNotifications.start(debugMode: true)

// Production (production + minimal logs)
PushNotifications.start(debugMode: false)

// Advanced configuration (if you need more control)
PushNotifications.start(
    environment: .sandbox,
    debugMode: true,
    autoRequestPermissions: false,
    autoSetupDelegates: true
)
```

### Delegate Management

```swift
// Add listener
PushNotifications.shared?.addDelegate(self)

// Check permissions
PushNotifications.shared?.checkPermissions()

// Access configured bundle ID
let bundleId = PushNotifications.shared?.bundleId
```

### Delegate Methods

```swift
protocol PushNotificationsDelegate {
    // Token registered successfully
    func pushNotifications(_ pushNotifications: PushNotifications, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: String)
    
    // Registration error
    func pushNotifications(_ pushNotifications: PushNotifications, didFailToRegisterForRemoteNotificationsWithError error: Error)
    
    // Notification received
    func pushNotifications(_ pushNotifications: PushNotifications, didReceiveRemoteNotification userInfo: [String: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    
    // Permission status changed
    func pushNotifications(_ pushNotifications: PushNotifications, permissionStatusChanged status: UNAuthorizationStatus)
}
```

## Usage Examples

### SwiftUI Integration

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Just one line! Automatic bundle ID
                    PushNotifications.start(debugMode: true)
                }
        }
    }
}
```

### With ObservableObject

```swift
class PushViewModel: ObservableObject, PushNotificationsDelegate {
    @Published var deviceToken: String?
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        PushNotifications.shared?.addDelegate(self)
    }
    
    func pushNotifications(_ pushNotifications: PushNotifications, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: String) {
        DispatchQueue.main.async {
            self.deviceToken = deviceToken
        }
    }
    
    func pushNotifications(_ pushNotifications: PushNotifications, permissionStatusChanged status: UNAuthorizationStatus) {
        DispatchQueue.main.async {
            self.permissionStatus = status
        }
    }
}
```

### Multiple Managers

```swift
// Analytics
class AnalyticsManager: PushNotificationsDelegate {
    func pushNotifications(_ pushNotifications: PushNotifications, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: String) {
        Analytics.setDeviceToken(deviceToken)
    }
}

// UI Updates
class UIManager: PushNotificationsDelegate {
    func pushNotifications(_ pushNotifications: PushNotifications, permissionStatusChanged status: UNAuthorizationStatus) {
        updateUI(for: status)
    }
}

// Configuration
let analytics = AnalyticsManager()
let ui = UIManager()

PushNotifications.shared?.addDelegate(analytics)
PushNotifications.shared?.addDelegate(ui)
```

## Debug Logs

In development mode, you'll see automatic logs like:

```
[PushNotifications] Initialized for development with bundle: com.myapp.example
[PushNotifications] Requesting notification permissions...
[PushNotifications] Permissions granted: authorized
[PushNotifications] Registering for remote notifications...
[PushNotifications] Token obtained: 1234567890abcdef...
[PushNotifications] Notification received in foreground
```

## Requirements

- iOS 12.0+
- Swift 5.9+
- Xcode 15.0+
- Push Notifications capability enabled

## Project Structure

```
AppAmbitPushNotifications/
├── Package.swift
├── Sources/
│   └── AppAmbitPushNotifications/
│       └── PushNotifications.swift
├── INTEGRATION_GUIDE.md
└── README.md
```

## Thread Safety

This SDK is fully thread-safe and compatible with Swift 6 Concurrency:

- Uses `@unchecked Sendable` following AppAmbit patterns
- All operations are synchronized with DispatchQueues
- Delegates execute in a thread-safe manner

## SDK Philosophy

This SDK follows the **minimal configuration** philosophy:

1. **One line to start**: `PushNotifications.setupForDevelopment(bundleId: "...")`
2. **Auto-configuration**: Takes care of setting up all delegates automatically
3. **Listener pattern**: Uses delegates for maximum flexibility
4. **Auto debug**: Detailed logs in development without extra configuration

## Complete Documentation

- [Integration Guide](INTEGRATION_GUIDE.md) - Step-by-step tutorial
- See `PushNotificationsView.swift` in the example app for complete code

## Support

For questions or issues, check the example application included in the AppAmbit project.