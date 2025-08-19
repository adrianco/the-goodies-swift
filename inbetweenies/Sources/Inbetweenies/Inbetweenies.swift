/**
 * File: Inbetweenies.swift
 * Purpose: Core protocol package for distributed knowledge graph synchronization
 * 
 * CONTEXT:
 * Inbetweenies defines the shared protocol and data models used by both
 * client (Wildthing) and server (FunkyGibbon) for maintaining consistency
 * in a distributed smart home knowledge graph system.
 * 
 * FUNCTIONALITY:
 * - Entity and EntityRelationship data models
 * - Vector clock implementation for causality tracking
 * - Conflict resolution strategies
 * - Sync protocol definitions
 * - MCP (Model Context Protocol) message types
 * 
 * PYTHON PARITY:
 * Corresponds to inbetweenies package in Python implementation
 * - ✅ Entity and relationship models
 * - ✅ Vector clock implementation
 * - ✅ Conflict resolution
 * - ✅ Sync protocol types
 * - ⚠️  Graph operations (partial implementation)
 * - ⚠️  MCP message handling (not yet implemented)
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial protocol implementation
 */

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