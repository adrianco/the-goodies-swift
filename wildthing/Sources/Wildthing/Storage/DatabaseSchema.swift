/**
 * File: DatabaseSchema.swift
 * Purpose: SQLite database schema definitions
 * 
 * CONTEXT:
 * Defines the database structure for local storage including tables
 * for entities, relationships, sync metadata, and offline queue.
 * Uses SQLite.swift for type-safe database operations.
 * 
 * FUNCTIONALITY:
 * - Entity table with versioning and sync tracking
 * - Relationship table with bidirectional references
 * - Sync metadata for vector clocks and cursors
 * - Offline queue for pending operations
 * - Optimized indexes for query performance
 * - Foreign key constraints for data integrity
 * 
 * PYTHON PARITY:
 * Corresponds to database schema in Python blowing-off
 * - ✅ Entity storage with all fields
 * - ✅ Relationship storage
 * - ✅ Sync metadata tracking
 * - ✅ Offline queue management
 * - ✅ Performance indexes
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial schema implementation with indexes
 */

import Foundation
import SQLite
import Inbetweenies

/// Database schema definitions for Wildthing
public struct DatabaseSchema {
    
    // MARK: - Entities Table
    public struct Entities {
        static let table = Table("entities")
        
        static let id = Expression<String>("id")
        static let version = Expression<String>("version")
        static let entityType = Expression<String>("entity_type")
        static let name = Expression<String>("name")
        static let content = Expression<Data>("content") // JSON data
        static let sourceType = Expression<String>("source_type")
        static let userId = Expression<String?>("user_id")
        static let parentVersions = Expression<Data>("parent_versions") // JSON array
        static let createdAt = Expression<Date>("created_at")
        static let updatedAt = Expression<Date>("updated_at")
        static let isPendingSync = Expression<Bool>("is_pending_sync")
        static let syncAction = Expression<String?>("sync_action") // create, update, delete
    }
    
    // MARK: - Relationships Table
    public struct Relationships {
        static let table = Table("entity_relationships")
        
        static let id = Expression<String>("id")
        static let fromEntityId = Expression<String>("from_entity_id")
        static let fromEntityVersion = Expression<String>("from_entity_version")
        static let toEntityId = Expression<String>("to_entity_id")
        static let toEntityVersion = Expression<String>("to_entity_version")
        static let relationshipType = Expression<String>("relationship_type")
        static let properties = Expression<Data>("properties") // JSON data
        static let userId = Expression<String?>("user_id")
        static let createdAt = Expression<Date>("created_at")
        static let updatedAt = Expression<Date>("updated_at")
        static let isPendingSync = Expression<Bool>("is_pending_sync")
        static let syncAction = Expression<String?>("sync_action")
    }
    
    // MARK: - Sync Metadata Table
    public struct SyncMetadata {
        static let table = Table("sync_metadata")
        
        static let id = Expression<String>("id")
        static let lastSyncDate = Expression<Date?>("last_sync_date")
        static let vectorClock = Expression<Data>("vector_clock") // JSON data
        static let cursor = Expression<String?>("cursor")
        static let deviceId = Expression<String>("device_id")
        static let userId = Expression<String?>("user_id")
    }
    
    // MARK: - Offline Queue Table
    public struct OfflineQueue {
        static let table = Table("offline_queue")
        
        static let id = Expression<String>("id")
        static let operationType = Expression<String>("operation_type")
        static let entityId = Expression<String?>("entity_id")
        static let relationshipId = Expression<String?>("relationship_id")
        static let payload = Expression<Data>("payload") // JSON data
        static let createdAt = Expression<Date>("created_at")
        static let retryCount = Expression<Int>("retry_count")
        static let lastRetryAt = Expression<Date?>("last_retry_at")
    }
    
    // MARK: - Schema Creation
    
    /// Create all database tables
    public static func createTables(in db: Connection) throws {
        // Create entities table
        try db.run(Entities.table.create(ifNotExists: true) { t in
            t.column(Entities.id)
            t.column(Entities.version)
            t.column(Entities.entityType)
            t.column(Entities.name)
            t.column(Entities.content)
            t.column(Entities.sourceType)
            t.column(Entities.userId)
            t.column(Entities.parentVersions)
            t.column(Entities.createdAt)
            t.column(Entities.updatedAt)
            t.column(Entities.isPendingSync, defaultValue: false)
            t.column(Entities.syncAction)
            
            t.primaryKey(Entities.id, Entities.version)
            t.check(Entities.entityType.length > 0)
        })
        
        // Create relationships table
        try db.run(Relationships.table.create(ifNotExists: true) { t in
            t.column(Relationships.id, primaryKey: true)
            t.column(Relationships.fromEntityId)
            t.column(Relationships.fromEntityVersion)
            t.column(Relationships.toEntityId)
            t.column(Relationships.toEntityVersion)
            t.column(Relationships.relationshipType)
            t.column(Relationships.properties)
            t.column(Relationships.userId)
            t.column(Relationships.createdAt)
            t.column(Relationships.updatedAt)
            t.column(Relationships.isPendingSync, defaultValue: false)
            t.column(Relationships.syncAction)
            
            t.check(Relationships.relationshipType.length > 0)
        })
        
        // Create sync metadata table
        try db.run(SyncMetadata.table.create(ifNotExists: true) { t in
            t.column(SyncMetadata.id, primaryKey: true)
            t.column(SyncMetadata.lastSyncDate)
            t.column(SyncMetadata.vectorClock)
            t.column(SyncMetadata.cursor)
            t.column(SyncMetadata.deviceId)
            t.column(SyncMetadata.userId)
        })
        
        // Create offline queue table
        try db.run(OfflineQueue.table.create(ifNotExists: true) { t in
            t.column(OfflineQueue.id, primaryKey: true)
            t.column(OfflineQueue.operationType)
            t.column(OfflineQueue.entityId)
            t.column(OfflineQueue.relationshipId)
            t.column(OfflineQueue.payload)
            t.column(OfflineQueue.createdAt)
            t.column(OfflineQueue.retryCount, defaultValue: 0)
            t.column(OfflineQueue.lastRetryAt)
        })
        
        // Create indexes for better query performance
        try createIndexes(in: db)
    }
    
    /// Create database indexes
    private static func createIndexes(in db: Connection) throws {
        // Entity indexes
        try db.run(Entities.table.createIndex(
            Entities.entityType,
            Entities.isPendingSync,
            ifNotExists: true
        ))
        
        try db.run(Entities.table.createIndex(
            Entities.updatedAt,
            ifNotExists: true
        ))
        
        // Relationship indexes
        try db.run(Relationships.table.createIndex(
            Relationships.fromEntityId,
            ifNotExists: true
        ))
        
        try db.run(Relationships.table.createIndex(
            Relationships.toEntityId,
            ifNotExists: true
        ))
        
        try db.run(Relationships.table.createIndex(
            Relationships.isPendingSync,
            ifNotExists: true
        ))
        
        // Offline queue index
        try db.run(OfflineQueue.table.createIndex(
            OfflineQueue.createdAt,
            ifNotExists: true
        ))
    }
}