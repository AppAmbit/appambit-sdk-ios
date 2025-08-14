 import Foundation

 final class NetworkState: @unchecked Sendable  {
     static let shared = NetworkState()

     private var status: ReachabilityService.NetworkStatus = .disconnected
     
     private init() {}

     var isConnected: Bool {
         switch status {
         case .connected: return true
         case .disconnected: return false
         }
     }

     var connectionType: ReachabilityService.ConnectionType {
         switch status {
         case .connected(let type): return type
         case .disconnected: return .unavailable
         }
     }

     func configure(with reachability: ReachabilityService) {
         try? reachability.startMonitoring { [weak self] newStatus in
             self?.status = newStatus
         }

         if reachability.isConnected() {
             status = .connected(reachability.connectionType)
         } else {
             status = .disconnected
         }
     }
 }
