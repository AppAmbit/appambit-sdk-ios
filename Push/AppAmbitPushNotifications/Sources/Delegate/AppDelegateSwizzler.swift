import UIKit
import ObjectiveC

/// Core engine for "Zero-Config" registration.
@objc class AppDelegateSwizzler: NSObject {
    
    private nonisolated(unsafe) static var hasSwizzled = false
    private nonisolated(unsafe) static var swizzledClasses = Set<String>()
    private nonisolated(unsafe) static let lock = NSRecursiveLock()
    
    @objc static func swizzleAppDelegateMethods() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !hasSwizzled else { return }
        hasSwizzled = true
        
        PushLogger.log("Activating swizzling...")
        
        RobustSwizzler.swizzle(
            targetClass: UIApplication.self,
            originalSelector: #selector(setter: UIApplication.delegate),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_setDelegate(_:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
        
        if let appDelegate = UIApplication.shared.delegate {
            swizzleMethods(for: appDelegate)
        } else {
            NotificationCenter.default.addObserver(forName: UIApplication.didFinishLaunchingNotification, object: nil, queue: .main) { _ in
                if let finalDelegate = UIApplication.shared.delegate {
                    swizzleMethods(for: finalDelegate)
                }
            }
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    @objc func swizzled_setDelegate(_ delegate: UIApplicationDelegate?) {
        if let delegate = delegate {
            AppDelegateSwizzler.swizzleMethods(for: delegate)
        }
        
        let selector = #selector(AppDelegateSwizzler.swizzled_setDelegate(_:))
        if self.responds(to: selector) {
            self.perform(selector, with: delegate)
        }
    }
    
    fileprivate static func swizzleMethods(for delegate: UIApplicationDelegate) {
        let delegateClass: AnyClass = object_getClass(delegate)!
        let className = String(describing: delegateClass)
        
        lock.lock()
        if swizzledClasses.contains(className) {
            lock.unlock()
            return
        }
        swizzledClasses.insert(className)
        lock.unlock()
        
        RobustSwizzler.swizzle(
            targetClass: delegateClass,
            originalSelector: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_didRegisterForRemoteNotifications(_:deviceToken:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
        
        RobustSwizzler.swizzle(
            targetClass: delegateClass,
            originalSelector: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
            swizzledSelector: #selector(AppDelegateSwizzler.swizzled_didFailToRegisterForRemoteNotifications(_:error:)),
            swizzlerClass: AppDelegateSwizzler.self
        )
    }
    
    @objc dynamic func swizzled_didRegisterForRemoteNotifications(_ application: UIApplication, deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        PushLogger.log("New APNs token received: \(tokenString)")
        PushKernel.handleNewToken(tokenString)
        
        let selector = #selector(AppDelegateSwizzler.swizzled_didRegisterForRemoteNotifications(_:deviceToken:))
        if self.responds(to: selector) {
            self.perform(selector, with: application, with: deviceToken)
        }
    }
    
    @objc dynamic func swizzled_didFailToRegisterForRemoteNotifications(_ application: UIApplication, error: Error) {
        PushLogger.error("Registration error: \(error.localizedDescription)")

        let selector = #selector(AppDelegateSwizzler.swizzled_didFailToRegisterForRemoteNotifications(_:error:))
        if self.responds(to: selector) {
            self.perform(selector, with: application, with: error)
        }
    }
}

private class RobustSwizzler {
    static func swizzle(targetClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector, swizzlerClass: AnyClass) {
        
        guard let swizzledMethod = class_getInstanceMethod(swizzlerClass, swizzledSelector) else {
            PushLogger.error("Method \(swizzledSelector) not found.")
            return
        }
        
        let implementation = method_getImplementation(swizzledMethod)
        let typeEncoding = method_getTypeEncoding(swizzledMethod)
        
        if let originalMethod = class_getInstanceMethod(targetClass, originalSelector) {
            class_addMethod(targetClass, swizzledSelector, implementation, typeEncoding)
            if let newMethod = class_getInstanceMethod(targetClass, swizzledSelector) {
                method_exchangeImplementations(originalMethod, newMethod)
                PushLogger.log("Swizzled \(originalSelector)")
            }
        } else {
            class_addMethod(targetClass, originalSelector, implementation, typeEncoding)
            PushLogger.log("Injected \(originalSelector)")
        }
    }
}
