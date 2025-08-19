/// Wildthing - Swift client for The Goodies distributed MCP knowledge graph
///
/// This package provides a Swift client implementation for synchronizing
/// with FunkyGibbon servers, with local storage and offline capabilities.

import Foundation

/// Package information
public struct Wildthing {
    /// Package version
    public static let version = "2.0.0"
    
    /// Package description
    public static let description = "Swift client for distributed knowledge graph synchronization with SQLite persistence"
    
    /// Default configuration for quick setup
    public static func defaultConfiguration() -> Configuration {
        return Configuration()
    }
    
    private init() {}
}

// Re-export the full implementation as the default client
@available(iOS 15.0, macOS 12.0, *)
public typealias WildthingClient = WildthingClientV2