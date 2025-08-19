import Foundation
import Network
import Combine

/// Monitors network connectivity
@available(iOS 15.0, macOS 12.0, *)
public class NetworkMonitor: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionType: ConnectionType = .unknown
    @Published public private(set) var isExpensive: Bool = false
    @Published public private(set) var isConstrained: Bool = false
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "wildthing.network.monitor")
    
    // MARK: - Connection Type
    
    public enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case other
        case unknown
    }
    
    // MARK: - Initialization
    
    public init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network changes
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateConnectionStatus(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network changes
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if a specific host is reachable
    public func isHostReachable(_ host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let parameters = NWParameters()
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(443) // HTTPS port
            )
            
            let connection = NWConnection(to: endpoint, using: parameters)
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.cancel()
                    continuation.resume(returning: true)
                    
                case .failed, .cancelled:
                    continuation.resume(returning: false)
                    
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            // Timeout after 5 seconds
            queue.asyncAfter(deadline: .now() + 5) {
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .other
        } else {
            connectionType = .unknown
        }
    }
}

// MARK: - Network Reachability Helper

@available(iOS 15.0, macOS 12.0, *)
public class NetworkReachability {
    
    /// Check if we can reach the sync server
    public static func canReachServer(at url: URL?) async -> Bool {
        guard let url = url,
              let host = url.host else {
            return false
        }
        
        let monitor = NetworkMonitor()
        return await monitor.isHostReachable(host)
    }
    
    /// Wait for network to become available
    public static func waitForNetwork(timeout: TimeInterval = 30) async -> Bool {
        let monitor = NetworkMonitor()
        monitor.startMonitoring()
        defer { monitor.stopMonitoring() }
        
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if monitor.isConnected {
                return true
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        return false
    }
}