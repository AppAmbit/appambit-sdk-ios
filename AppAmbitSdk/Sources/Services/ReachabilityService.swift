import Foundation
import SystemConfiguration

public final class ReachabilityService {

    public enum ConnectionType: String {
        case wifi
        case cellular
        case unavailable
    }

    public enum NetworkStatus {
        case connected(ConnectionType)
        case disconnected
    }

    public typealias StatusChangeHandler = @Sendable (NetworkStatus) -> Void

    private var reachabilityRef: SCNetworkReachability?
    private let monitorQueue = DispatchQueue(label: "com.appambit.networkmonitor")
    private var previousFlags: SCNetworkReachabilityFlags?
    private var _callback: StatusChangeHandler?

    public init?() {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)

        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
            return nil
        }

        self.reachabilityRef = ref
    }

    deinit {
        stop()
    }

    public func startMonitoring(_ onStatusChange: @escaping StatusChangeHandler) throws {
        guard let ref = reachabilityRef else { return }

        monitorQueue.sync {
            self._callback = onStatusChange
        }

        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: { info in UnsafeRawPointer(info) },
            release: { _ in },
            copyDescription: nil
        )

        let callback: SCNetworkReachabilityCallBack = { (_, flags, info) in
            guard let info = info else { return }
            let monitor = Unmanaged<ReachabilityService>.fromOpaque(info).takeUnretainedValue()
            monitor.flagsDidChange(flags)
        }

        if !SCNetworkReachabilitySetCallback(ref, callback, &context) {
            throw NSError(domain: "NetworkMonitor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to set callback"])
        }

        if !SCNetworkReachabilitySetDispatchQueue(ref, monitorQueue) {
            throw NSError(domain: "NetworkMonitor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to set dispatch queue"])
        }

        // Emit initial status
        var initialFlags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(ref, &initialFlags) {
            flagsDidChange(initialFlags)
        }
    }
    
    public func isConnected() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        guard let ref = reachabilityRef,
              SCNetworkReachabilityGetFlags(ref, &flags) else {
            return false
        }

        self.flagsDidChange(flags)

        return Self.isReachable(flags)
    }


    public func stop() {
        guard let ref = reachabilityRef else { return }
        SCNetworkReachabilitySetCallback(ref, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(ref, nil)

        monitorQueue.sync {
            _callback = nil
        }
    }

    public var connectionType: ConnectionType {
        guard let flags = currentFlags, Self.isReachable(flags) else {
            return .unavailable
        }
        return Self.mapConnectionType(from: flags)
    }

    private var currentFlags: SCNetworkReachabilityFlags? {
        guard let ref = reachabilityRef else { return nil }
        var flags = SCNetworkReachabilityFlags()
        return SCNetworkReachabilityGetFlags(ref, &flags) ? flags : nil
    }

    private static func isReachable(_ flags: SCNetworkReachabilityFlags) -> Bool {
        guard flags.contains(.reachable) else { return false }

        if flags.contains(.connectionRequired) &&
            !(flags.contains(.connectionOnTraffic) || flags.contains(.connectionOnDemand)) {
            return false
        }

        if flags.contains(.interventionRequired) {
            return false
        }

        return true
    }

    private static func mapConnectionType(from flags: SCNetworkReachabilityFlags) -> ConnectionType {
        #if os(iOS)
        return flags.contains(.isWWAN) ? .cellular : .wifi
        #else
        return .wifi
        #endif
    }

    private func flagsDidChange(_ flags: SCNetworkReachabilityFlags) {
        guard flags != previousFlags else { return }
        previousFlags = flags

        let connection = Self.isReachable(flags)
            ? NetworkStatus.connected(Self.mapConnectionType(from: flags))
            : .disconnected

        let callbackCopy = _callback

        DispatchQueue.main.async {
            callbackCopy?(connection)
        }
    }
}
