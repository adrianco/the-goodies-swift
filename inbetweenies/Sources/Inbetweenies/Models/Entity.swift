/**
 * File: Entity.swift
 * Purpose: Core Entity model for knowledge graph nodes
 * 
 * CONTEXT:
 * Defines the fundamental data structure for nodes in the distributed
 * knowledge graph. Entities represent smart home devices, locations,
 * users, and other domain objects with versioning support for
 * conflict-free replicated data types (CRDT).
 * 
 * FUNCTIONALITY:
 * - Unique identification with UUID
 * - Version tracking for conflict resolution
 * - Flexible content storage with AnyCodable
 * - Parent version tracking for causality
 * - Type classification (device, location, user, etc.)
 * - Source tracking (manual, homekit, matter, etc.)
 * - Conversion to/from sync change representations
 * 
 * PYTHON PARITY:
 * Corresponds to Entity class in Python inbetweenies
 * - ✅ All fields match Python implementation
 * - ✅ Codable for JSON serialization
 * - ✅ Version and parent version tracking
 * - ✅ EntityType and SourceType enumerations
 * - ✅ Change representation for sync
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial Entity implementation with full type support
 */

import Foundation

/// Entity types in the knowledge graph
public enum EntityType: String, CaseIterable, Codable {
    case home = "home"
    case room = "room"
    case device = "device"
    case zone = "zone"
    case door = "door"
    case window = "window"
    case procedure = "procedure"
    case manual = "manual"
    case note = "note"
    case schedule = "schedule"
    case automation = "automation"
    case app = "app"
}

/// Source of entity data
public enum SourceType: String, Codable {
    case homekit = "homekit"
    case matter = "matter"
    case manual = "manual"
    case imported = "imported"
    case generated = "generated"
}

/// Generic entity representing any node in the knowledge graph
public struct Entity: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let version: String
    public let entityType: EntityType
    public let name: String
    public let content: [String: AnyCodable]
    public let sourceType: SourceType
    public let userId: String?
    public let parentVersions: [String]
    public let createdAt: Date
    public let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case entityType = "entity_type"
        case name
        case content
        case sourceType = "source_type"
        case userId = "user_id"
        case parentVersions = "parent_versions"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: String = UUID().uuidString,
        version: String = UUID().uuidString,
        entityType: EntityType,
        name: String,
        content: [String: AnyCodable] = [:],
        sourceType: SourceType = .manual,
        userId: String? = nil,
        parentVersions: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.version = version
        self.entityType = entityType
        self.name = name
        self.content = content
        self.sourceType = sourceType
        self.userId = userId
        self.parentVersions = parentVersions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(version)
    }
    
    // Equatable conformance
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        lhs.id == rhs.id && lhs.version == rhs.version
    }
}

// MARK: - Entity Extensions for Sync

public extension Entity {
    /// Convert to EntityChange for sync operations
    func toEntityChange() -> EntityChange {
        EntityChange(
            id: id,
            version: version,
            entityType: entityType.rawValue,
            name: name,
            content: content.mapValues { $0.value },
            sourceType: sourceType.rawValue,
            userId: userId ?? "",
            parentVersions: parentVersions,
            checksum: nil
        )
    }
}

/// Entity change representation for sync
public struct EntityChange: Codable {
    public let id: String
    public let version: String
    public let entityType: String
    public let name: String
    public let content: [String: Any]
    public let sourceType: String
    public let userId: String
    public let parentVersions: [String]
    public let checksum: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case entityType = "entity_type"
        case name
        case content
        case sourceType = "source_type"
        case userId = "user_id"
        case parentVersions = "parent_versions"
        case checksum
    }
    
    public init(
        id: String,
        version: String,
        entityType: String,
        name: String,
        content: [String: Any],
        sourceType: String,
        userId: String,
        parentVersions: [String],
        checksum: String?
    ) {
        self.id = id
        self.version = version
        self.entityType = entityType
        self.name = name
        self.content = content
        self.sourceType = sourceType
        self.userId = userId
        self.parentVersions = parentVersions
        self.checksum = checksum
    }
    
    // Custom encoding for content
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(entityType, forKey: .entityType)
        try container.encode(name, forKey: .name)
        try container.encode(content.mapValues { AnyCodable($0) }, forKey: .content)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encode(userId, forKey: .userId)
        try container.encode(parentVersions, forKey: .parentVersions)
        try container.encodeIfPresent(checksum, forKey: .checksum)
    }
    
    // Custom decoding for content
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        version = try container.decode(String.self, forKey: .version)
        entityType = try container.decode(String.self, forKey: .entityType)
        name = try container.decode(String.self, forKey: .name)
        
        let codableContent = try container.decode([String: AnyCodable].self, forKey: .content)
        content = codableContent.mapValues { $0.value }
        
        sourceType = try container.decode(String.self, forKey: .sourceType)
        userId = try container.decode(String.self, forKey: .userId)
        parentVersions = try container.decode([String].self, forKey: .parentVersions)
        checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
    }
    
    /// Convert back to Entity
    public func toEntity() -> Entity? {
        guard let type = EntityType(rawValue: entityType),
              let source = SourceType(rawValue: sourceType) else {
            return nil
        }
        
        return Entity(
            id: id,
            version: version,
            entityType: type,
            name: name,
            content: content.mapValues { AnyCodable($0) },
            sourceType: source,
            userId: userId.isEmpty ? nil : userId,
            parentVersions: parentVersions,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}