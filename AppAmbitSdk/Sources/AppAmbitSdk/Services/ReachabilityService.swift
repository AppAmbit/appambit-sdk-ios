import SystemConfiguration
import Foundation

public final class ReachabilityService: @unchecked Sendable {

    public enum ConnectionStatus {
        case connected
        case disconnected
    }
    
    private var reachabilityRef: SCNetworkReachability
    private let queue = DispatchQueue(label: "com.appambit.simplereachability")
    private var previousFlags: SCNetworkReachabilityFlags?
    
    public var onConnectionChange: (@Sendable (ConnectionStatus) -> Void)?

    
    private var weakifier: ReachabilityWeakifier?
    
    public var isConnected: Bool {
        queue.sync {
            guard let flags = currentFlags else { return false }
            return isNetworkReachable(with: flags)
        }
    }
    
    private var currentFlags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()
        return SCNetworkReachabilityGetFlags(reachabilityRef, &flags) ? flags : nil
    }
    
    // MARK: - Initialization
    
    public init() throws {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
            throw NSError(domain: "SimpleReachability", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create reachability reference"])
        }
        
        self.reachabilityRef = ref
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    public func initialize() throws {
        try queue.sync {
            guard weakifier == nil else { return }
            
            let weakifier = ReachabilityWeakifier(reachability: self)
            self.weakifier = weakifier

            let opaqueWeakifier = Unmanaged.passUnretained(weakifier).toOpaque()
            
            let callback: SCNetworkReachabilityCallBack = { (_, flags, info) in
                guard let info = info else { return }

                let weakifier = Unmanaged<ReachabilityWeakifier>.fromOpaque(info).takeUnretainedValue()
                weakifier.reachability?.queue.async {
                    weakifier.reachability?.notifyConnectionChange(flags: flags)
                }
            }
            
            var context = SCNetworkReachabilityContext(
                version: 0,
                info: opaqueWeakifier,
                retain: { info in
                    let unmanaged = Unmanaged<ReachabilityWeakifier>.fromOpaque(info)
                    _ = unmanaged.retain()
                    return UnsafeRawPointer(unmanaged.toOpaque())
                },
                release: { info in
                    let unmanaged = Unmanaged<ReachabilityWeakifier>.fromOpaque(info)
                    unmanaged.release()
                },
                copyDescription: nil
            )
            
            if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
                throw NSError(domain: "SimpleReachability", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to set reachability callback"])
            }
            
            if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, queue) {
                throw NSError(domain: "SimpleReachability", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to set reachability queue"])
            }
            
            if let flags = currentFlags {
                notifyConnectionChange(flags: flags)
            }
        }
    }
    
    public func stopMonitoring() {
        queue.sync {
            SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
            SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
            weakifier = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        
        return isReachable && (!needsConnection || canConnectWithoutUserInteraction)
    }
    
    private func notifyConnectionChange(flags: SCNetworkReachabilityFlags) {
        guard flags != previousFlags else { return }
        previousFlags = flags
        
        let isConnected = isNetworkReachable(with: flags)
        let status: ConnectionStatus = isConnected ? .connected : .disconnected
        
        DispatchQueue.main.async { [onConnectionChange] in
            onConnectionChange?(status)
        }
    }
}

private class ReachabilityWeakifier {
    weak var reachability: ReachabilityService?
    init(reachability: ReachabilityService) {
        self.reachability = reachability
    }
}
