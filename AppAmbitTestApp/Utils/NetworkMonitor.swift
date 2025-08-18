import AppAmbit

class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let reachabilityService: ReachabilityService?

    var isConnected: Bool {
        return reachabilityService?.isConnected() ?? false
    }

    private init() {
        self.reachabilityService = ReachabilityService()
        if reachabilityService == nil {
            debugPrint("Error: ReachabilityService could not be initialized")
        }
    }
}
