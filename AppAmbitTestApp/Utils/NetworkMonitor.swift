import AppAmbit

import AppAmbit

class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let reachabilityService: ReachabilityService?

    var isConnected: Bool {
        return reachabilityService?.isConnected ?? false
    }

    private init() {
        do {
            reachabilityService = try ReachabilityService()
        } catch {
            reachabilityService = nil
            debugPrint("Error initializing ReachabilityServic: \(error.localizedDescription)")
        }
    }
}
