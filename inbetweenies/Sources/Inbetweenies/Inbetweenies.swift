/// Inbetweenies - Shared synchronization protocol for The Goodies distributed MCP knowledge graph
///
/// This package provides the core models and protocols for synchronizing
/// smart home knowledge graphs between clients and servers.

import Foundation

// Re-export all public types for convenient importing
public typealias InbetweeniesEntity = Entity
public typealias InbetweeniesRelationship = EntityRelationship

/// Package information
public struct Inbetweenies {
    /// Package version
    public static let version = "1.0.0"
    
    /// Protocol version for sync operations
    public static let protocolVersion = "inbetweenies-v2"
    
    /// Package description
    public static let description = "Shared synchronization protocol for distributed knowledge graphs"
    
    private init() {}
}