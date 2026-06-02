## Version 1.0.1

### AppAmbit

* **[Fix]** Fixed consumer sync being skipped on app start and network reconnect due to incorrect deduplication: `updateConsumer` called with no explicit token/push-enabled now always forces a backend sync regardless of stored state.

* **[Fix]** Corrected push-enabled default value read from storage (`false` instead of `true`) to accurately reflect the initial disabled state.

* **[Refactor]** `ConsumerService` now holds its own `ApiService` reference (injected at init) instead of accessing `ServiceContainer.shared.apiService` directly, enabling proper unit testing.

___

## Version 1.0.0

### AppAmbit Push Notifications

* **[Breaking Change]** Standardized push notification payload structure: The APNs data is now mapped into a unified cross-platform schema. The payload passed to notification listeners now features top-level fields and nested platform-specific `ios` sub-objects, replacing the previous flat format.

* **[Breaking Change]** Updated listener payload mappings to align with the new core SDK architectures.

* **[Feature]** Added `AppAmbitNotificationService` base class for Swift extensions, introducing new methods for pre-display processing:
  * `didReceive(_:withContentHandler:)`
  * `handlePayload(_:content:)`
  * `serviceExtensionTimeWillExpire()`

## Version 0.5.0

### AppAmbit

* **[Feature]** Added support for CMS (Content Management System) integration, allowing dynamic content updates and management within the app without requiring app updates. Using fluent API design for easy integration and configuration of CMS features.

## Version 0.4.0

### AppAmbit

* **[Feature]** Added option to send breadcrumbs only on crashes to improve performance and resource efficiency.

## Version 0.3.1

### AppAmbit

* **[Refactor]** Updated RemoteConfig method `getInt` to `getLong` to be more precise with the size of values that the method can handle

## Version 0.3.0

### AppAmbit

* **[Feature]** - Added Remote Config support to AppAmbit, allowing dynamic configuration of app behavior without requiring app updates.

## Version 0.2.0

### AppAmbit Push Notifications

* **[Feature]** - Added support for push notification messaging via AppAmbit dashboard

## Version 0.1.2

## AppAmbit

* **[Fix]** - Fixed incorrect Ambit Trails tracking when the app is opened from Notification Center and when presenting `UIAlertController` on iOS

## Version 0.1.1

### AppAmbit

* **[Internal]** Ambit Trail integration for hybrid platforms (no user-facing changes)

## Version 0.1.0

### AppAmbit

* **[Feature]** Add Ambit Trail – records user navigation, app lifecycle events, network activity, and errors to provide deeper context for debugging and issue analysis

___

## Version 0.0.9

### Fix
- Fixed bug in detecting user app version

___

## Version 0.0.8

### Changes
- AppAmbit description updated