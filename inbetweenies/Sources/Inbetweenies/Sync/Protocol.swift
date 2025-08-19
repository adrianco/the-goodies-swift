import Foundation

// MARK: - Sync Types

/// Types of synchronization
public enum SyncType: String, Codable {
    case full = "full"
    case delta = "delta"
    case entities = "entities"
    case relationships = "relationships"
}

/// Change types for sync operations
public enum ChangeType: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
}

// MARK: - Sync Request

/// Sync request from client to server
public struct SyncRequest: Codable {
    public let protocolVersion: String
    public let deviceId: String
    public let userId: String
    public let syncType: SyncType
    public let vectorClock: VectorClock
    public let changes: [SyncChange]
    public let cursor: String?
    public let filters: SyncFilters?
    
    private enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case deviceId = "device_id"
        case userId = "user_id"
        case syncType = "sync_type"
        case vectorClock = "vector_clock"
        case changes
        case cursor
        case filters
    }
    
    public init(
        deviceId: String,
        userId: String,
        syncType: SyncType,
        vectorClock: VectorClock = VectorClock(),
        changes: [SyncChange] = [],
        cursor: String? = nil,
        filters: SyncFilters? = nil
    ) {
        self.protocolVersion = "inbetweenies-v2"
        self.deviceId = deviceId
        self.userId = userId
        self.syncType = syncType
        self.vectorClock = vectorClock
        self.changes = changes
        self.cursor = cursor
        self.filters = filters
    }
}

// MARK: - Sync Response

/// Sync response from server to client
public struct SyncResponse: Codable {
    public let protocolVersion: String
    public let syncType: SyncType
    public let changes: [SyncChange]
    public let conflicts: [ConflictInfo]
    public let vectorClock: VectorClock
    public let cursor: String?
    public let syncStats: SyncStats
    
    private enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol_version"
        case syncType = "sync_type"
        case changes
        case conflicts
        case vectorClock = "vector_clock"
        case cursor
        case syncStats = "sync_stats"
    }
}

// MARK: - Sync Change

/// Individual change in sync
public struct SyncChange: Codable {
    public let changeType: ChangeType
    public let entity: EntityChange?
    public let relationships: [RelationshipChange]
    
    private enum CodingKeys: String, CodingKey {
        case changeType = "change_type"
        case entity
        case relationships
    }
    
    public init(
        changeType: ChangeType,
        entity: EntityChange? = nil,
        relationships: [RelationshipChange] = []
    ) {
        self.changeType = changeType
        self.entity = entity
        self.relationships = relationships
    }
}

// MARK: - Sync Filters

/// Filters for sync request
public struct SyncFilters: Codable {
    public let entityTypes: [String]?
    public let since: Date?
    public let modifiedBy: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case entityTypes = "entity_types"
        case since
        case modifiedBy = "modified_by"
    }
    
    public init(
        entityTypes: [String]? = nil,
        since: Date? = nil,
        modifiedBy: [String]? = nil
    ) {
        self.entityTypes = entityTypes
        self.since = since
        self.modifiedBy = modifiedBy
    }
}

// MARK: - Sync Stats

/// Sync statistics
public struct SyncStats: Codable {
    public let entitiesSynced: Int
    public let relationshipsSynced: Int
    public let conflictsResolved: Int
    public let durationMs: Double
    
    private enum CodingKeys: String, CodingKey {
        case entitiesSynced = "entities_synced"
        case relationshipsSynced = "relationships_synced"
        case conflictsResolved = "conflicts_resolved"
        case durationMs = "duration_ms"
    }
    
    public init(
        entitiesSynced: Int = 0,
        relationshipsSynced: Int = 0,
        conflictsResolved: Int = 0,
        durationMs: Double = 0
    ) {
        self.entitiesSynced = entitiesSynced
        self.relationshipsSynced = relationshipsSynced
        self.conflictsResolved = conflictsResolved
        self.durationMs = durationMs
    }
}

// MARK: - Sync Result

/// Result of a sync operation
public struct SyncResult {
    public let entitiesSynced: Int
    public let relationshipsSynced: Int
    public let conflictsResolved: Int
    public let duration: Double
    
    public init(
        entitiesSynced: Int,
        relationshipsSynced: Int,
        conflictsResolved: Int,
        duration: Double
    ) {
        self.entitiesSynced = entitiesSynced
        self.relationshipsSynced = relationshipsSynced
        self.conflictsResolved = conflictsResolved
        self.duration = duration
    }
}