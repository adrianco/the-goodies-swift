/// Wildthing - Swift client for The Goodies distributed MCP knowledge graph
///
/// This package provides a Swift client implementation for synchronizing
/// with FunkyGibbon servers, with local storage and offline capabilities.

import Foundation

/// Package information
public struct Wildthing {
    /// Package version
    public static let version = "1.0.0"
    
    /// Package description
    public static let description = "Swift client for distributed knowledge graph synchronization"
    
    /// Default configuration for quick setup
    public static func defaultConfiguration() -> Configuration {
        return Configuration()
    }
    
    private init() {}
}