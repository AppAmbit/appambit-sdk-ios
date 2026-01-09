import Foundation
import UserNotifications
import AppAmbit
import UIKit

/// PushNotifications - Public API for push notifications
/// This is the facade that connects the decoupled PushKernel with the AppAmbit Core SDK.
/// This class replicates the Android PushNotifications.java architecture.
@objcMembers
public final class PushNotifications: NSObject {
    private static let tag = "AppAmbitPushSDK"
    private static let enableSyncState = EnableSyncState()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Type Aliases
    
    public typealias PermissionListener = (Bool) -> Void
    
    /// Closure type for customizing notification content before it's displayed.
    /// - Parameters:
    ///   - content: Mutable notification content that can be modified
    ///   - notification: The parsed AppAmbit notification model
    public typealias NotificationCustomizer = (UNMutableNotificationContent, AppAmbitNotification) -> Void
    
    // MARK: - Public API
    
    /// Sets a customizer closure to modify notification content before it's displayed
    /// This customizer is invoked before the notification is shown to the user
    @nonobjc
    public static func setNotificationCustomizer(_ customizer: NotificationCustomizer?) {
        PushKernel.setNotificationCustomizer(customizer)
    }
    
    /// Starts the Push Notifications SDK
    /// Must be called after AppAmbit.start()
    public static func start() {
        guard AppAmbit.isInitialized() else {
            debugPrint("[\(tag)] AppAmbit SDK has not been started. Please call AppAmbit.start() before starting the Push SDK.")
            return
        }

        debugPrint("[\(tag)] Starting Push SDK and binding to AppAmbit Core.")

        syncPermissionStatus { didSync in
            guard !didSync else { return }
            if PushKernel.isNotificationsEnabled(),
               let currentToken = PushKernel.getCurrentToken(),
               !currentToken.isEmpty {
                debugPrint("[\(tag)] Push SDK started. Syncing current token with backend.")
                ConsumerService.shared.updateConsumer(deviceToken: currentToken, pushEnabled: true)
            }
        }
        
        // Set up token listener to sync with backend
        PushKernel.setTokenListener(TokenListenerImpl())
        
        // Start the kernel
        PushKernel.start()
    }
    
    /// Enables or disables push notifications at both the business and APNs levels.
    ///
    /// When set to false, this method will:
    /// 1. Update the AppAmbit dashboard to reflect that the user has opted out.
    /// 2. Unregister from APNs to stop the device from receiving push notifications.
    ///
    /// When set to true, a new APNs token will be fetched and sent to the AppAmbit dashboard.
    ///
    /// - Parameter enabled: true to enable notifications, false to disable.
    public static func setNotificationsEnabled(_ enabled: Bool) {
        setNotificationsEnabled(enabled, completion: nil)
    }
    
    /// Enables or disables push notifications and optionally reports when APNs + backend sync completes.
    ///
    /// - Parameters:
    ///   - enabled: true to enable notifications, false to disable.
    ///   - completion: Called when backend sync finishes (true if success).
    public static func setNotificationsEnabled(
        _ enabled: Bool,
        completion: (@Sendable (Bool) -> Void)?
    ) {
        guard AppAmbit.isInitialized() else {
            debugPrint("[\(tag)] AppAmbit SDK is not initialized. Cannot set notification status.")
            DispatchQueue.main.async { completion?(false) }
            return
        }
        
        debugPrint("[\(tag)] Setting notifications enabled state to: \(enabled)")
        
        if !enabled {
            resolvePendingEnableCompletion(success: false)
            ConsumerService.shared.updateConsumer(deviceToken: nil, pushEnabled: false, completion: completion)
            PushKernel.setNotificationsEnabled(false)
            return
        }
        
        enableSyncState.setWaiting(completion: completion)
        
        // Update local state and register for notifications; backend sync happens on APNs token.
        PushKernel.setNotificationsEnabled(true)

        // If a token already exists (or is stored), sync immediately instead of waiting for a new token.
        let existingToken = PushKernel.getCurrentToken()
        ConsumerService.shared.updateConsumer(deviceToken: existingToken, pushEnabled: true) { success in
            if success {
                PushNotifications.resolvePendingEnableCompletion(success: true)
            }
        }
    }
    
    /// Checks if push notifications are currently enabled by the user.
    ///
    /// - Returns: true if notifications are enabled, false otherwise.
    public static func isNotificationsEnabled() -> Bool {
        return PushKernel.isNotificationsEnabled()
    }
    
    /// Requests notification permissions from the user.
    /// - Parameter listener: Optional callback to receive permission result (true if granted, false otherwise)
    public static func requestNotificationPermission(listener: PermissionListener? = nil) {
        PushKernel.requestNotificationPermission(
            listener: PermissionListenerWrapper(
                listener: listener,
                postHandler: { granted in
                    PushNotifications.setNotificationsEnabled(granted)
                }
            )
        )
    }

    private static func syncPermissionStatus(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .denied:
                setNotificationsEnabled(false)
                completion?(true)
            case .authorized, .provisional, .ephemeral:
                setNotificationsEnabled(true)
                completion?(true)
            case .notDetermined:
                setNotificationsEnabled(false)
                completion?(true)
            @unknown default:
                completion?(false)
            }
        }
    }
    
    // MARK: - Internal State Helpers
    
    fileprivate static func resolvePendingEnableCompletion(success: Bool) {
        guard let completion = enableSyncState.resolve(success: success) else { return }
        DispatchQueue.main.async {
            completion(success)
        }
    }
}

private final class EnableSyncState: @unchecked Sendable {
    private var pending: (@Sendable (Bool) -> Void)?
    private var isWaiting = false
    private let lock = NSLock()
    
    func setWaiting(completion: (@Sendable (Bool) -> Void)?) {
        lock.lock()
        pending = completion
        isWaiting = (completion != nil)
        lock.unlock()
    }
    
    func resolve(success: Bool) -> (@Sendable (Bool) -> Void)? {
        lock.lock()
        defer { lock.unlock() }
        guard isWaiting else { return nil }
        let completion = pending
        pending = nil
        isWaiting = false
        return completion
    }
}

// MARK: - Internal Listener Implementations

private final class TokenListenerImpl: PushKernel.TokenListener, @unchecked Sendable {
    func onNewToken(_ token: String) {
        DispatchQueue.main.async {
            if PushKernel.isNotificationsEnabled() {
                debugPrint("[AppAmbitPushSDK] APNs token received and notifications are enabled, updating consumer via AppAmbit Core.")
                ConsumerService.shared.updateConsumer(deviceToken: token, pushEnabled: true) { success in
                    PushNotifications.resolvePendingEnableCompletion(success: success)
                }
            }
        }
    }
}

private final class PermissionListenerWrapper: PushKernel.PermissionListener, @unchecked Sendable {
    private let listener: PushNotifications.PermissionListener?
    private let postHandler: ((Bool) -> Void)?

    init(listener: PushNotifications.PermissionListener?, postHandler: ((Bool) -> Void)?) {
        self.listener = listener
        self.postHandler = postHandler
    }

    func onPermissionResult(_ granted: Bool) {
        listener?(granted)
        postHandler?(granted)
    }
}
