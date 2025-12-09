import Foundation
import SystemConfiguration

final class ReachabilityService {

    public enum ConnectionType: String { case wifi, cellular, unavailable }

    private var reachabilityRef: SCNetworkReachability?

    public init?() {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return nil }
        self.reachabilityRef = ref
    }

    public func isConnected() -> Bool {
        var flags = SCNetworkReachabilityFlags()
        guard let ref = reachabilityRef,
              SCNetworkReachabilityGetFlags(ref, &flags) else {
            return false
        }
        return Self.isReachable(flags)
    }

    public var connectionType: ConnectionType {
        guard let flags = currentFlags, Self.isReachable(flags) else { return .unavailable }
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
            !(flags.contains(.connectionOnTraffic) || flags.contains(.connectionOnDemand)) { return false }
        if flags.contains(.interventionRequired) { return false }
        return true
    }

    private static func mapConnectionType(from flags: SCNetworkReachabilityFlags) -> ConnectionType {
        #if os(iOS)
        return flags.contains(.isWWAN) ? .cellular : .wifi
        #else
        return .wifi
        #endif
    }
}
