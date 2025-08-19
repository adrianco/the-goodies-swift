import Foundation

/// Strategies for resolving conflicts
public enum ConflictResolutionStrategy: String, Codable {
    case lastWriteWins = "last_write_wins"
    case firstWriteWins = "first_write_wins"
    case merge = "merge"
    case manual = "manual"
}

/// Information about a conflict
public struct ConflictInfo: Codable {
    public let entityId: String
    public let localVersion: String
    public let remoteVersion: String
    public let resolutionStrategy: ConflictResolutionStrategy
    public let resolvedVersion: String?
    
    private enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case localVersion = "local_version"
        case remoteVersion = "remote_version"
        case resolutionStrategy = "resolution_strategy"
        case resolvedVersion = "resolved_version"
    }
    
    public init(
        entityId: String,
        localVersion: String,
        remoteVersion: String,
        resolutionStrategy: ConflictResolutionStrategy,
        resolvedVersion: String? = nil
    ) {
        self.entityId = entityId
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.resolutionStrategy = resolutionStrategy
        self.resolvedVersion = resolvedVersion
    }
}

/// Conflict resolver for sync operations
public class ConflictResolver {
    
    public init() {}
    
    /// Resolve conflict between local and remote entities
    public func resolve(
        local: Entity,
        remote: Entity,
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) -> Entity {
        switch strategy {
        case .lastWriteWins:
            return resolveByLastWrite(local: local, remote: remote)
            
        case .firstWriteWins:
            return resolveByFirstWrite(local: local, remote: remote)
            
        case .merge:
            return mergeEntities(local: local, remote: remote)
            
        case .manual:
            // In production, this would trigger user intervention
            // For now, default to local version
            return local
        }
    }
    
    /// Resolve by taking the most recently updated entity
    private func resolveByLastWrite(local: Entity, remote: Entity) -> Entity {
        return local.updatedAt > remote.updatedAt ? local : remote
    }
    
    /// Resolve by taking the first created entity
    private func resolveByFirstWrite(local: Entity, remote: Entity) -> Entity {
        return local.createdAt < remote.createdAt ? local : remote
    }
    
    /// Merge two entities intelligently
    private func mergeEntities(local: Entity, remote: Entity) -> Entity {
        // Start with local entity as base
        var mergedContent = local.content
        
        // Add any keys from remote that don't exist in local
        for (key, value) in remote.content {
            if mergedContent[key] == nil {
                mergedContent[key] = value
            } else if let localValue = mergedContent[key] {
                // If both have the same key, use more recent based on update time
                if remote.updatedAt > local.updatedAt {
                    mergedContent[key] = value
                }
            }
        }
        
        // Create new version with both as parents
        let newVersion = UUID().uuidString
        var parentVersions = Set<String>()
        parentVersions.insert(local.version)
        parentVersions.insert(remote.version)
        parentVersions.formUnion(local.parentVersions)
        parentVersions.formUnion(remote.parentVersions)
        
        // Use the most recent name
        let name = local.updatedAt > remote.updatedAt ? local.name : remote.name
        
        return Entity(
            id: local.id,
            version: newVersion,
            entityType: local.entityType,
            name: name,
            content: mergedContent,
            sourceType: local.sourceType,
            userId: local.userId ?? remote.userId,
            parentVersions: Array(parentVersions).sorted(),
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: Date()
        )
    }
    
    /// Detect if two entities are in conflict
    public func hasConflict(local: Entity, remote: Entity) -> Bool {
        // Entities are in conflict if they have the same ID but different versions
        // and neither version is a parent of the other
        guard local.id == remote.id else { return false }
        guard local.version != remote.version else { return false }
        
        // Check if one is a parent of the other
        if local.parentVersions.contains(remote.version) ||
           remote.parentVersions.contains(local.version) {
            return false
        }
        
        return true
    }
    
    /// Resolve conflicts for a batch of entity pairs
    public func resolveBatch(
        conflicts: [(local: Entity, remote: Entity)],
        strategy: ConflictResolutionStrategy = .lastWriteWins
    ) -> [Entity] {
        return conflicts.map { conflict in
            resolve(local: conflict.local, remote: conflict.remote, strategy: strategy)
        }
    }
}