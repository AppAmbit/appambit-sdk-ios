import Foundation
import UIKit

/// Automatically intercepts APNs token registration without requiring app-side AppDelegate implementation
final class APNsTokenInterceptor: NSObject {
    private static let tag = "APNsTokenInterceptor"
    private nonisolated(unsafe) static var hasSwizzled = false
    private nonisolated(unsafe) static var originalImplementation: IMP?
    private nonisolated(unsafe) static var originalFailureImplementation: IMP?
    
    static func setup() {
        guard !hasSwizzled else { return }
        hasSwizzled = true
        if Thread.isMainThread {
            performSetup()
        } else {
            DispatchQueue.main.async {
                performSetup()
            }
        }
    }

    private static func performSetup() {
        guard let appDelegate = UIApplication.shared.delegate else {
            print("[\(tag)] No app delegate found")
            return
        }
        
        let appDelegateClass: AnyClass = type(of: appDelegate)
        swizzleTokenRegistration(in: appDelegateClass)
    }
    
    private static func swizzleTokenRegistration(in targetClass: AnyClass) {
        let originalSelector = #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        let swizzledSelector = #selector(APNsTokenInterceptor.interceptedApplication(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        
        guard let swizzledMethod = class_getInstanceMethod(APNsTokenInterceptor.self, swizzledSelector) else {
            print("[\(tag)] Failed to get swizzled method")
            return
        }
        
        let swizzledIMP = method_getImplementation(swizzledMethod)
        let swizzledTypes = method_getTypeEncoding(swizzledMethod)
        
        if let originalMethod = class_getInstanceMethod(targetClass, originalSelector) {
            // Original exists - store it and replace with our implementation
            let originalIMP = method_getImplementation(originalMethod)
            originalImplementation = originalIMP
            method_setImplementation(originalMethod, swizzledIMP)
            print("[\(tag)] Swizzled didRegisterForRemoteNotificationsWithDeviceToken")
        } else {
            // Original doesn't exist - just add our implementation
            if class_addMethod(targetClass, originalSelector, swizzledIMP, swizzledTypes) {
                print("[\(tag)] Added didRegisterForRemoteNotificationsWithDeviceToken")
            } else {
                print("[\(tag)] Failed to add didRegisterForRemoteNotificationsWithDeviceToken")
            }
        }

        swizzleTokenFailure(in: targetClass)
    }

    private static func swizzleTokenFailure(in targetClass: AnyClass) {
        let originalSelector = #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:))
        let swizzledSelector = #selector(APNsTokenInterceptor.interceptedApplication(_:didFailToRegisterForRemoteNotificationsWithError:))

        guard let swizzledMethod = class_getInstanceMethod(APNsTokenInterceptor.self, swizzledSelector) else {
            print("[\(tag)] Failed to get swizzled failure method")
            return
        }

        let swizzledIMP = method_getImplementation(swizzledMethod)
        let swizzledTypes = method_getTypeEncoding(swizzledMethod)

        if let originalMethod = class_getInstanceMethod(targetClass, originalSelector) {
            let originalIMP = method_getImplementation(originalMethod)
            originalFailureImplementation = originalIMP
            method_setImplementation(originalMethod, swizzledIMP)
            print("[\(tag)] Swizzled didFailToRegisterForRemoteNotificationsWithError")
        } else {
            if class_addMethod(targetClass, originalSelector, swizzledIMP, swizzledTypes) {
                print("[\(tag)] Added didFailToRegisterForRemoteNotificationsWithError")
            } else {
                print("[\(tag)] Failed to add didFailToRegisterForRemoteNotificationsWithError")
            }
        }
    }
    
    @objc private dynamic func interceptedApplication(_ application: UIApplication,
                                                      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        // Forward to PushKernel
        PushKernel.handleNewToken(token)
        
        // Call original implementation if it existed
        if let originalIMP = APNsTokenInterceptor.originalImplementation {
            typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, Data) -> Void
            let originalFunc = unsafeBitCast(originalIMP, to: OriginalFunction.self)
            originalFunc(self, #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)), application, deviceToken)
        }
    }

    @objc private dynamic func interceptedApplication(_ application: UIApplication,
                                                      didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[\(Self.tag)] Failed to register for remote notifications: \(error.localizedDescription)")

        if let originalIMP = APNsTokenInterceptor.originalFailureImplementation {
            typealias OriginalFunction = @convention(c) (AnyObject, Selector, UIApplication, Error) -> Void
            let originalFunc = unsafeBitCast(originalIMP, to: OriginalFunction.self)
            originalFunc(self, #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)), application, error)
        }
    }
}
