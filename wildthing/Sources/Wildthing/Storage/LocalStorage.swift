import Foundation
import SQLite
import Inbetweenies
import Combine

/// Local storage manager using SQLite
public class LocalStorage {
    
    // MARK: - Properties
    
    private let db: Connection
    private let configuration: Configuration
    private let queue = DispatchQueue(label: "wildthing.storage", qos: .userInitiated)
    
    private let pendingChangesSubject = CurrentValueSubject<Int, Never>(0)
    public var pendingChangesPublisher: AnyPublisher<Int, Never> {
        pendingChangesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration) throws {
        self.configuration = configuration
        
        // Create database connection
        let documentsPath = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first!
        
        let dbPath = "\(documentsPath)/\(configuration.databasePath)"
        self.db = try Connection(dbPath)
        
        // Enable foreign keys
        try db.execute("PRAGMA foreign_keys = ON")
        
        // Create tables
        try DatabaseSchema.createTables(in: db)
        
        // Initialize sync metadata if needed
        try initializeSyncMetadata()
    }
    
    // MARK: - Entity Operations
    
    /// Create a new entity
    public func createEntity(_ entity: Entity) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let contentData = try JSONEncoder().encode(entity.content)
                    let parentVersionsData = try JSONEncoder().encode(entity.parentVersions)
                    
                    let insert = DatabaseSchema.Entities.table.insert(
                        DatabaseSchema.Entities.id <- entity.id,
                        DatabaseSchema.Entities.version <- entity.version,
                        DatabaseSchema.Entities.entityType <- entity.entityType.rawValue,
                        DatabaseSchema.Entities.name <- entity.name,
                        DatabaseSchema.Entities.content <- contentData,
                        DatabaseSchema.Entities.sourceType <- entity.sourceType.rawValue,
                        DatabaseSchema.Entities.userId <- entity.userId,
                        DatabaseSchema.Entities.parentVersions <- parentVersionsData,
                        DatabaseSchema.Entities.createdAt <- entity.createdAt,
                        DatabaseSchema.Entities.updatedAt <- entity.updatedAt,
                        DatabaseSchema.Entities.isPendingSync <- true,
                        DatabaseSchema.Entities.syncAction <- "create"
                    )
                    
                    try self.db.run(insert)
                    self.updatePendingChangesCount()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Update an existing entity
    public func updateEntity(_ entity: Entity) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let contentData = try JSONEncoder().encode(entity.content)
                    let parentVersionsData = try JSONEncoder().encode(entity.parentVersions)
                    
                    let entityRow = DatabaseSchema.Entities.table.filter(
                        DatabaseSchema.Entities.id == entity.id &&
                        DatabaseSchema.Entities.version == entity.version
                    )
                    
                    let update = entityRow.update(
                        DatabaseSchema.Entities.name <- entity.name,
                        DatabaseSchema.Entities.content <- contentData,
                        DatabaseSchema.Entities.sourceType <- entity.sourceType.rawValue,
                        DatabaseSchema.Entities.userId <- entity.userId,
                        DatabaseSchema.Entities.parentVersions <- parentVersionsData,
                        DatabaseSchema.Entities.updatedAt <- Date(),
                        DatabaseSchema.Entities.isPendingSync <- true,
                        DatabaseSchema.Entities.syncAction <- "update"
                    )
                    
                    let rowsUpdated = try self.db.run(update)
                    if rowsUpdated == 0 {
                        // Entity doesn't exist, create it
                        try self.db.run(DatabaseSchema.Entities.table.insert(
                            DatabaseSchema.Entities.id <- entity.id,
                            DatabaseSchema.Entities.version <- entity.version,
                            DatabaseSchema.Entities.entityType <- entity.entityType.rawValue,
                            DatabaseSchema.Entities.name <- entity.name,
                            DatabaseSchema.Entities.content <- contentData,
                            DatabaseSchema.Entities.sourceType <- entity.sourceType.rawValue,
                            DatabaseSchema.Entities.userId <- entity.userId,
                            DatabaseSchema.Entities.parentVersions <- parentVersionsData,
                            DatabaseSchema.Entities.createdAt <- entity.createdAt,
                            DatabaseSchema.Entities.updatedAt <- entity.updatedAt,
                            DatabaseSchema.Entities.isPendingSync <- true,
                            DatabaseSchema.Entities.syncAction <- "update"
                        ))
                    }
                    
                    self.updatePendingChangesCount()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Delete an entity
    public func deleteEntity(id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    // Mark for deletion instead of actual delete for sync
                    let entityRow = DatabaseSchema.Entities.table.filter(
                        DatabaseSchema.Entities.id == id
                    )
                    
                    let update = entityRow.update(
                        DatabaseSchema.Entities.isPendingSync <- true,
                        DatabaseSchema.Entities.syncAction <- "delete"
                    )
                    
                    try self.db.run(update)
                    self.updatePendingChangesCount()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Get entity by ID
    public func getEntity(id: String) async throws -> Entity? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let query = DatabaseSchema.Entities.table.filter(
                        DatabaseSchema.Entities.id == id &&
                        DatabaseSchema.Entities.syncAction != "delete"
                    ).order(DatabaseSchema.Entities.version.desc).limit(1)
                    
                    if let row = try self.db.pluck(query) {
                        let entity = try self.entityFromRow(row)
                        continuation.resume(returning: entity)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// List entities
    public func listEntities(type: EntityType? = nil) async throws -> [Entity] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    var query = DatabaseSchema.Entities.table.filter(
                        DatabaseSchema.Entities.syncAction != "delete"
                    )
                    
                    if let type = type {
                        query = query.filter(DatabaseSchema.Entities.entityType == type.rawValue)
                    }
                    
                    let entities = try self.db.prepare(query).compactMap { row in
                        try? self.entityFromRow(row)
                    }
                    
                    continuation.resume(returning: entities)
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Relationship Operations
    
    /// Create a relationship
    public func createRelationship(_ relationship: EntityRelationship) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let propertiesData = try JSONEncoder().encode(relationship.properties)
                    
                    let insert = DatabaseSchema.Relationships.table.insert(
                        DatabaseSchema.Relationships.id <- relationship.id,
                        DatabaseSchema.Relationships.fromEntityId <- relationship.fromEntityId,
                        DatabaseSchema.Relationships.fromEntityVersion <- relationship.fromEntityVersion,
                        DatabaseSchema.Relationships.toEntityId <- relationship.toEntityId,
                        DatabaseSchema.Relationships.toEntityVersion <- relationship.toEntityVersion,
                        DatabaseSchema.Relationships.relationshipType <- relationship.relationshipType.rawValue,
                        DatabaseSchema.Relationships.properties <- propertiesData,
                        DatabaseSchema.Relationships.userId <- relationship.userId,
                        DatabaseSchema.Relationships.createdAt <- relationship.createdAt,
                        DatabaseSchema.Relationships.updatedAt <- relationship.updatedAt,
                        DatabaseSchema.Relationships.isPendingSync <- true,
                        DatabaseSchema.Relationships.syncAction <- "create"
                    )
                    
                    try self.db.run(insert)
                    self.updatePendingChangesCount()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Delete a relationship
    public func deleteRelationship(id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let relationshipRow = DatabaseSchema.Relationships.table.filter(
                        DatabaseSchema.Relationships.id == id
                    )
                    
                    let update = relationshipRow.update(
                        DatabaseSchema.Relationships.isPendingSync <- true,
                        DatabaseSchema.Relationships.syncAction <- "delete"
                    )
                    
                    try self.db.run(update)
                    self.updatePendingChangesCount()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Get relationships for an entity
    public func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let query = DatabaseSchema.Relationships.table.filter(
                        (DatabaseSchema.Relationships.fromEntityId == entityId ||
                         DatabaseSchema.Relationships.toEntityId == entityId) &&
                        DatabaseSchema.Relationships.syncAction != "delete"
                    )
                    
                    let relationships = try self.db.prepare(query).compactMap { row in
                        try? self.relationshipFromRow(row)
                    }
                    
                    continuation.resume(returning: relationships)
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    /// Get pending changes for sync
    public func getPendingChanges() async throws -> [SyncChange] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    var changes: [SyncChange] = []
                    
                    // Get pending entities
                    let pendingEntities = DatabaseSchema.Entities.table.filter(
                        DatabaseSchema.Entities.isPendingSync == true
                    )
                    
                    for row in try self.db.prepare(pendingEntities) {
                        if let entity = try? self.entityFromRow(row),
                           let action = row[DatabaseSchema.Entities.syncAction],
                           let changeType = ChangeType(rawValue: action) {
                            
                            let change = SyncChange(
                                changeType: changeType,
                                entity: entity.toEntityChange(),
                                relationships: []
                            )
                            changes.append(change)
                        }
                    }
                    
                    // Get pending relationships
                    let pendingRelationships = DatabaseSchema.Relationships.table.filter(
                        DatabaseSchema.Relationships.isPendingSync == true
                    )
                    
                    for row in try self.db.prepare(pendingRelationships) {
                        if let relationship = try? self.relationshipFromRow(row),
                           let action = row[DatabaseSchema.Relationships.syncAction],
                           let changeType = ChangeType(rawValue: action) {
                            
                            let change = SyncChange(
                                changeType: changeType,
                                entity: nil,
                                relationships: [relationship.toRelationshipChange()]
                            )
                            changes.append(change)
                        }
                    }
                    
                    continuation.resume(returning: changes)
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Clear pending sync flags
    public func clearPendingChanges() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    // Clear entity pending flags
                    try self.db.run(DatabaseSchema.Entities.table.update(
                        DatabaseSchema.Entities.isPendingSync <- false,
                        DatabaseSchema.Entities.syncAction <- nil
                    ))
                    
                    // Clear relationship pending flags
                    try self.db.run(DatabaseSchema.Relationships.table.update(
                        DatabaseSchema.Relationships.isPendingSync <- false,
                        DatabaseSchema.Relationships.syncAction <- nil
                    ))
                    
                    // Clean up deleted items
                    try self.db.run(DatabaseSchema.Entities.table
                        .filter(DatabaseSchema.Entities.syncAction == "delete")
                        .delete())
                    
                    try self.db.run(DatabaseSchema.Relationships.table
                        .filter(DatabaseSchema.Relationships.syncAction == "delete")
                        .delete())
                    
                    self.pendingChangesSubject.send(0)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Clear all data
    public func clearAll() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    try self.db.run(DatabaseSchema.Entities.table.delete())
                    try self.db.run(DatabaseSchema.Relationships.table.delete())
                    try self.db.run(DatabaseSchema.OfflineQueue.table.delete())
                    
                    self.pendingChangesSubject.send(0)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Sync Metadata
    
    /// Get sync metadata
    public func getSyncMetadata() async throws -> (deviceId: String, vectorClock: VectorClock, cursor: String?) {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let query = DatabaseSchema.SyncMetadata.table.limit(1)
                    
                    if let row = try self.db.pluck(query) {
                        let clockData = row[DatabaseSchema.SyncMetadata.vectorClock]
                        let vectorClock = try JSONDecoder().decode(VectorClock.self, from: clockData)
                        
                        continuation.resume(returning: (
                            deviceId: row[DatabaseSchema.SyncMetadata.deviceId],
                            vectorClock: vectorClock,
                            cursor: row[DatabaseSchema.SyncMetadata.cursor]
                        ))
                    } else {
                        continuation.resume(returning: (
                            deviceId: UUID().uuidString,
                            vectorClock: VectorClock(),
                            cursor: nil
                        ))
                    }
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    /// Update sync metadata
    public func updateSyncMetadata(vectorClock: VectorClock, cursor: String?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.storageError("Storage deallocated"))
                    return
                }
                
                do {
                    let clockData = try JSONEncoder().encode(vectorClock)
                    
                    // Try to update existing record
                    let update = DatabaseSchema.SyncMetadata.table.update(
                        DatabaseSchema.SyncMetadata.vectorClock <- clockData,
                        DatabaseSchema.SyncMetadata.cursor <- cursor,
                        DatabaseSchema.SyncMetadata.lastSyncDate <- Date()
                    )
                    
                    let rowsUpdated = try self.db.run(update)
                    
                    // If no rows updated, insert new record
                    if rowsUpdated == 0 {
                        let deviceId = UUID().uuidString
                        try self.db.run(DatabaseSchema.SyncMetadata.table.insert(
                            DatabaseSchema.SyncMetadata.id <- UUID().uuidString,
                            DatabaseSchema.SyncMetadata.deviceId <- deviceId,
                            DatabaseSchema.SyncMetadata.vectorClock <- clockData,
                            DatabaseSchema.SyncMetadata.cursor <- cursor,
                            DatabaseSchema.SyncMetadata.lastSyncDate <- Date()
                        ))
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: WildthingError.storageError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeSyncMetadata() throws {
        let count = try db.scalar(DatabaseSchema.SyncMetadata.table.count)
        if count == 0 {
            let deviceId = UUID().uuidString
            let vectorClock = VectorClock()
            let clockData = try JSONEncoder().encode(vectorClock)
            
            try db.run(DatabaseSchema.SyncMetadata.table.insert(
                DatabaseSchema.SyncMetadata.id <- UUID().uuidString,
                DatabaseSchema.SyncMetadata.deviceId <- deviceId,
                DatabaseSchema.SyncMetadata.vectorClock <- clockData
            ))
        }
    }
    
    private func entityFromRow(_ row: Row) throws -> Entity {
        let contentData = row[DatabaseSchema.Entities.content]
        let content = try JSONDecoder().decode([String: AnyCodable].self, from: contentData)
        
        let parentVersionsData = row[DatabaseSchema.Entities.parentVersions]
        let parentVersions = try JSONDecoder().decode([String].self, from: parentVersionsData)
        
        guard let entityType = EntityType(rawValue: row[DatabaseSchema.Entities.entityType]),
              let sourceType = SourceType(rawValue: row[DatabaseSchema.Entities.sourceType]) else {
            throw WildthingError.invalidData("Invalid entity type or source type")
        }
        
        return Entity(
            id: row[DatabaseSchema.Entities.id],
            version: row[DatabaseSchema.Entities.version],
            entityType: entityType,
            name: row[DatabaseSchema.Entities.name],
            content: content,
            sourceType: sourceType,
            userId: row[DatabaseSchema.Entities.userId],
            parentVersions: parentVersions,
            createdAt: row[DatabaseSchema.Entities.createdAt],
            updatedAt: row[DatabaseSchema.Entities.updatedAt]
        )
    }
    
    private func relationshipFromRow(_ row: Row) throws -> EntityRelationship {
        let propertiesData = row[DatabaseSchema.Relationships.properties]
        let properties = try JSONDecoder().decode([String: AnyCodable].self, from: propertiesData)
        
        guard let relationshipType = RelationshipType(rawValue: row[DatabaseSchema.Relationships.relationshipType]) else {
            throw WildthingError.invalidData("Invalid relationship type")
        }
        
        return EntityRelationship(
            id: row[DatabaseSchema.Relationships.id],
            fromEntityId: row[DatabaseSchema.Relationships.fromEntityId],
            fromEntityVersion: row[DatabaseSchema.Relationships.fromEntityVersion],
            toEntityId: row[DatabaseSchema.Relationships.toEntityId],
            toEntityVersion: row[DatabaseSchema.Relationships.toEntityVersion],
            relationshipType: relationshipType,
            properties: properties,
            userId: row[DatabaseSchema.Relationships.userId],
            createdAt: row[DatabaseSchema.Relationships.createdAt],
            updatedAt: row[DatabaseSchema.Relationships.updatedAt]
        )
    }
    
    private func updatePendingChangesCount() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let entitiesCount = try self.db.scalar(
                    DatabaseSchema.Entities.table
                        .filter(DatabaseSchema.Entities.isPendingSync == true)
                        .count
                )
                
                let relationshipsCount = try self.db.scalar(
                    DatabaseSchema.Relationships.table
                        .filter(DatabaseSchema.Relationships.isPendingSync == true)
                        .count
                )
                
                self.pendingChangesSubject.send(entitiesCount + relationshipsCount)
            } catch {
                // Ignore errors in count update
            }
        }
    }
}