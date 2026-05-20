import Foundation
import UserNotifications
import UIKit
import AppAmbit

/// Public facade for managing AppAmbit Push Notifications.
@objc(PushNotifications)
public class PushNotifications: NSObject {
    
    public typealias PermissionListener = (Bool) -> Void
    
    /// Starts the Push Notification SDK.
    public static func start(debugMode: Bool = false, autoRequestPermissions: Bool = false) {
        PushLogger.debugMode = debugMode
        PushLogger.log("Starting Push SDK...")

        AppAmbitPushRegistration.setup()
        PushKernel.setTokenListener(TokenListenerImpl())

        if autoRequestPermissions {
            requestNotificationPermission(listener: nil)
        }
    }
    
    @objc(start)
    public static func startObjC() {
        start()
    }
    
    @objc
    public static func setNotificationsEnabled(_ enabled: Bool) {
        PushLogger.log("Setting notifications enabled to: \(enabled)")
        PushKernel.setNotificationsEnabled(enabled)
        
        let token = PushKernel.getCurrentToken()
        ConsumerService.shared.updateConsumer(deviceToken: token, pushEnabled: enabled)
    }
    
    @objc
    public static func isNotificationsEnabled() -> Bool {
        return PushKernel.isNotificationsEnabled()
    }
    
    public static func requestNotificationPermission(listener: PermissionListener?) {
        PushKernel.requestNotificationPermission(listener: listener != nil ? PermissionListenerWrapper(listener: listener!) : nil)
    }

    @objc(requestNotificationPermissionWithListener:)
    public static func requestNotificationPermissionObjC(listener: ((Bool)->Void)?) {
        requestNotificationPermission(listener: listener)
    }

    @objc
    public static func hasNotificationPermission() -> Bool {
        return PushKernel.hasNotificationPermission()
    }

    @objc(setNotificationListener:)
    public static func setNotificationListener(_ listener: @escaping ([AnyHashable: Any], PushNotificationState) -> Void) {
        PushLogger.log("Notification listener registered.")
        PushKernel.setNotificationListener(listener)
    }
}

private class TokenListenerImpl: PushKernel.TokenListener {
    func onNewToken(_ token: String) {
        sync(token: token, allowRetry: true)
    }

    private func sync(token: String, allowRetry: Bool) {
        guard AppAmbit.isInitialized() else {
            if allowRetry {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.sync(token: token, allowRetry: false)
                }
            } else {
                PushLogger.error("AppAmbit not initialized; dropping push token.")
            }
            return
        }

        DispatchQueue.main.async {
            if PushKernel.isNotificationsEnabled() {
                PushLogger.log("Syncing token with backend...")
                ConsumerService.shared.updateConsumer(deviceToken: token, pushEnabled: true) { success in
                    if success {
                        PushLogger.log("Token synced successfully.")
                    } else {
                        PushLogger.error("Failed to sync token.")
                    }
                }
            } else {
                PushLogger.log("Token received but notifications are disabled.")
            }
        }
    }
}

private class PermissionListenerWrapper: PushKernel.PermissionListener {
    private let listener: PushNotifications.PermissionListener
    
    init(listener: @escaping PushNotifications.PermissionListener) {
        self.listener = listener
    }
    
    func onPermissionResult(_ granted: Bool) {
        listener(granted)
    }
}
