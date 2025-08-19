/**
 * File: EntityRelationship.swift
 * Purpose: Relationship model for knowledge graph edges
 * 
 * CONTEXT:
 * Defines relationships (edges) between entities in the knowledge graph.
 * Relationships are versioned and support properties for storing
 * metadata about the connection between entities.
 * 
 * FUNCTIONALITY:
 * - Bidirectional relationships with version tracking
 * - Typed relationships (locatedIn, controls, monitors, etc.)
 * - Property storage for relationship metadata
 * - Version tracking for both source and target entities
 * - Conversion to/from sync change representations
 * 
 * PYTHON PARITY:
 * Corresponds to EntityRelationship in Python inbetweenies
 * - ✅ All relationship types match Python
 * - ✅ Property storage with AnyCodable
 * - ✅ Bidirectional version tracking
 * - ✅ Change representation for sync
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial relationship implementation
 */

import Foundation

/// Types of relationships between entities
public enum RelationshipType: String, CaseIterable, Codable {
    case locatedIn = "located_in"
    case controls = "controls"
    case connectsTo = "connects_to"
    case partOf = "part_of"
    case manages = "manages"
    case documentedBy = "documented_by"
    case procedureFor = "procedure_for"
    case triggeredBy = "triggered_by"
    case dependsOn = "depends_on"
    case containedIn = "contained_in"
    case monitors = "monitors"
    case automates = "automates"
    case controlledByApp = "controlled_by_app"
    case hasBlob = "has_blob"
}

/// Represents edges in the knowledge graph
public struct EntityRelationship: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let fromEntityId: String
    public let fromEntityVersion: String
    public let toEntityId: String
    public let toEntityVersion: String
    public let relationshipType: RelationshipType
    public let properties: [String: AnyCodable]
    public let userId: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case fromEntityId = "from_entity_id"
        case fromEntityVersion = "from_entity_version"
        case toEntityId = "to_entity_id"
        case toEntityVersion = "to_entity_version"
        case relationshipType = "relationship_type"
        case properties
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public init(
        id: String = UUID().uuidString,
        fromEntityId: String,
        fromEntityVersion: String,
        toEntityId: String,
        toEntityVersion: String,
        relationshipType: RelationshipType,
        properties: [String: AnyCodable] = [:],
        userId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fromEntityId = fromEntityId
        self.fromEntityVersion = fromEntityVersion
        self.toEntityId = toEntityId
        self.toEntityVersion = toEntityVersion
        self.relationshipType = relationshipType
        self.properties = properties
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    public static func == (lhs: EntityRelationship, rhs: EntityRelationship) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Relationship Extensions for Sync

public extension EntityRelationship {
    /// Convert to RelationshipChange for sync operations
    func toRelationshipChange() -> RelationshipChange {
        RelationshipChange(
            id: id,
            fromEntityId: fromEntityId,
            fromEntityVersion: fromEntityVersion,
            toEntityId: toEntityId,
            toEntityVersion: toEntityVersion,
            relationshipType: relationshipType.rawValue,
            properties: properties.mapValues { $0.value }
        )
    }
}

/// Relationship change representation for sync
public struct RelationshipChange: Codable {
    public let id: String
    public let fromEntityId: String
    public let fromEntityVersion: String
    public let toEntityId: String
    public let toEntityVersion: String
    public let relationshipType: String
    public let properties: [String: Any]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case fromEntityId = "from_entity_id"
        case fromEntityVersion = "from_entity_version"
        case toEntityId = "to_entity_id"
        case toEntityVersion = "to_entity_version"
        case relationshipType = "relationship_type"
        case properties
    }
    
    public init(
        id: String,
        fromEntityId: String,
        fromEntityVersion: String,
        toEntityId: String,
        toEntityVersion: String,
        relationshipType: String,
        properties: [String: Any]
    ) {
        self.id = id
        self.fromEntityId = fromEntityId
        self.fromEntityVersion = fromEntityVersion
        self.toEntityId = toEntityId
        self.toEntityVersion = toEntityVersion
        self.relationshipType = relationshipType
        self.properties = properties
    }
    
    // Custom encoding for properties
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fromEntityId, forKey: .fromEntityId)
        try container.encode(fromEntityVersion, forKey: .fromEntityVersion)
        try container.encode(toEntityId, forKey: .toEntityId)
        try container.encode(toEntityVersion, forKey: .toEntityVersion)
        try container.encode(relationshipType, forKey: .relationshipType)
        try container.encode(properties.mapValues { AnyCodable($0) }, forKey: .properties)
    }
    
    // Custom decoding for properties
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fromEntityId = try container.decode(String.self, forKey: .fromEntityId)
        fromEntityVersion = try container.decode(String.self, forKey: .fromEntityVersion)
        toEntityId = try container.decode(String.self, forKey: .toEntityId)
        toEntityVersion = try container.decode(String.self, forKey: .toEntityVersion)
        relationshipType = try container.decode(String.self, forKey: .relationshipType)
        
        let codableProperties = try container.decode([String: AnyCodable].self, forKey: .properties)
        properties = codableProperties.mapValues { $0.value }
    }
    
    /// Convert back to EntityRelationship
    public func toRelationship() -> EntityRelationship? {
        guard let type = RelationshipType(rawValue: relationshipType) else {
            return nil
        }
        
        return EntityRelationship(
            id: id,
            fromEntityId: fromEntityId,
            fromEntityVersion: fromEntityVersion,
            toEntityId: toEntityId,
            toEntityVersion: toEntityVersion,
            relationshipType: type,
            properties: properties.mapValues { AnyCodable($0) },
            userId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}