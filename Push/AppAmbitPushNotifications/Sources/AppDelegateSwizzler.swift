import UIKit
import ObjectiveC

/// Core engine for "Zero-Config" registration.
/// Uses method swizzling to automatically capture APNs tokens without manual AppDelegate modification.
@objc class AppDelegateSwizzler: NSObject {
    
    private nonisolated(unsafe) static var hasSwizzled = false
    private nonisolated(unsafe) static let lock = NSLock()
    
    /// Entry point to safely activate AppDelegate swizzling.
    @objc static func swizzleAppDelegateMethods() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !hasSwizzled else { return }
        hasSwizzled = true
        
        debugPrint("[AppAmbitPushSDK] Activating robust swizzling...")
        
        // 1. Swizzle UIApplication's delegate setter to detect when an AppDelegate is assigned
        RobustSwizzler.swizzle(
            targetClass: UIApplication.self,
            originalSelector: #selector(setter: UIApplication.delegate),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_setDelegate(_:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
        
        // 2. If an AppDelegate already exists, swizzle it immediately
        if let appDelegate = UIApplication.shared.delegate {
            debugPrint("[AppAmbitPushSDK] Existing AppDelegate found: \(type(of: appDelegate))")
            swizzleMethods(for: appDelegate)
        }
        
        // 3. Register for remote notifications on the main thread
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    /// Intercepts delegation assignment to the UIApplication.
    @objc func swizzled_setDelegate(_ delegate: UIApplicationDelegate?) {
        if let delegate = delegate {
            debugPrint("[AppAmbitPushSDK] Delegate intercepted: \(type(of: delegate))")
            AppDelegateSwizzler.swizzleMethods(for: delegate)
        }
        
        // Call the original implementation
        let selector = #selector(AppDelegateSwizzler.swizzled_setDelegate(_:))
        if self.responds(to: selector) {
            self.perform(selector, with: delegate)
        }
    }
    
    /// Swizzles specific push notification methods on the delegate class.
    fileprivate static func swizzleMethods(for delegate: UIApplicationDelegate) {
        let delegateClass: AnyClass = object_getClass(delegate)!
        
        // Swizzle for successful token registration
        RobustSwizzler.swizzle(
            targetClass: delegateClass,
            originalSelector: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_didRegisterForRemoteNotifications(_:deviceToken:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
        
        // Swizzle for failed token registration
        RobustSwizzler.swizzle(
            targetClass: delegateClass,
            originalSelector: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_didFailToRegisterForRemoteNotifications(_:error:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
    }
    
    /// Swizzled implementation of didRegisterForRemoteNotifications.
    @objc dynamic func swizzled_didRegisterForRemoteNotifications(_ application: UIApplication, deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        debugPrint("[AppAmbitPushSDK] Token intercepted by swizzling.")
        PushKernel.handleNewToken(tokenString)
        
        // Forward to original implementation if it exists
        let selector = #selector(AppDelegateSwizzler.swizzled_didRegisterForRemoteNotifications(_:deviceToken:))
        if self.responds(to: selector) {
            self.perform(selector, with: application, with: deviceToken)
        }
    }
    
    /// Swizzled implementation of didFailToRegisterForRemoteNotifications.
    @objc dynamic func swizzled_didFailToRegisterForRemoteNotifications(_ application: UIApplication, error: Error) {
        debugPrint("[AppAmbitPushSDK] Registration error intercepted: \(error.localizedDescription)")
        
        // Forward to original implementation if it exists
        let selector = #selector(AppDelegateSwizzler.swizzled_didFailToRegisterForRemoteNotifications(_:error:))
        if self.responds(to: selector) {
            self.perform(selector, with: application, with: error)
        }
    }
}

/// Utility for safely swapping method implementations between classes.
private class RobustSwizzler {
    static func swizzle(targetClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector, swizzlerClass: AnyClass) {
        
        guard let swizzledMethod = class_getInstanceMethod(swizzlerClass, swizzledSelector) else {
            debugPrint("[AppAmbitPushSDK] Error: \(swizzledSelector) not found in \(swizzlerClass)")
            return
        }
        
        let implementation = method_getImplementation(swizzledMethod)
        let typeEncoding = method_getTypeEncoding(swizzledMethod)
        
        if let originalMethod = class_getInstanceMethod(targetClass, originalSelector) {
            // Original exists, exchange implementations after adding our method to the target class
            class_addMethod(targetClass, swizzledSelector, implementation, typeEncoding)
            
            if let newMethod = class_getInstanceMethod(targetClass, swizzledSelector) {
                method_exchangeImplementations(originalMethod, newMethod)
                debugPrint("[AppAmbitPushSDK] Successfully swizzled \(originalSelector) in \(targetClass)")
            }
        } else {
            // Original missing, add our implementation as the primary method
            class_addMethod(targetClass, originalSelector, implementation, typeEncoding)
            debugPrint("[AppAmbitPushSDK] Injected \(originalSelector) into \(targetClass) (original was missing)")
        }
    }
}
