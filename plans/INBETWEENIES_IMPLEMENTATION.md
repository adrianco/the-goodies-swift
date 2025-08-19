# Inbetweenies Package Implementation Plan

## Overview
Detailed implementation plan for the Inbetweenies Swift package - the protocol layer providing shared synchronization models and utilities.

## Package Structure
```
inbetweenies/
├── Package.swift
├── Sources/
│   └── Inbetweenies/
│       ├── Models/
│       │   ├── Entity.swift
│       │   ├── EntityRelationship.swift
│       │   ├── Blob.swift
│       │   ├── SyncMetadata.swift
│       │   └── Base.swift
│       ├── Sync/
│       │   ├── Protocol.swift
│       │   ├── SyncTypes.swift
│       │   ├── VectorClock.swift
│       │   ├── ConflictResolver.swift
│       │   └── SyncResult.swift
│       ├── Graph/
│       │   ├── GraphOperations.swift
│       │   ├── GraphTraversal.swift
│       │   └── GraphSearch.swift
│       ├── MCP/
│       │   ├── MCPTool.swift
│       │   └── ToolDefinitions.swift
│       ├── Utils/
│       │   ├── JSONCoding.swift
│       │   ├── DateFormatters.swift
│       │   └── Checksum.swift
│       └── Inbetweenies.swift
└── Tests/
    └── InbetweeniesTests/
        ├── ModelTests/
        ├── SyncTests/
        ├── GraphTests/
        └── MCPTests/
```

## Implementation Details

### 1. Models Module

#### Entity.swift
```swift
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
public struct Entity: Codable, Identifiable, Equatable {
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
    
    public init(
        id: String = UUID().uuidString,
        version: String,
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
}
```

#### EntityRelationship.swift
```swift
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
public struct EntityRelationship: Codable, Identifiable, Equatable {
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
}
```

### 2. Sync Module

#### Protocol.swift
```swift
import Foundation

/// Sync request from client to server
public struct SyncRequest: Codable {
    public let protocolVersion: String = "inbetweenies-v2"
    public let deviceId: String
    public let userId: String
    public let syncType: SyncType
    public let vectorClock: VectorClock
    public let changes: [SyncChange]
    public let cursor: String?
    public let filters: SyncFilters?
    
    public init(
        deviceId: String,
        userId: String,
        syncType: SyncType,
        vectorClock: VectorClock = VectorClock(),
        changes: [SyncChange] = [],
        cursor: String? = nil,
        filters: SyncFilters? = nil
    ) {
        self.deviceId = deviceId
        self.userId = userId
        self.syncType = syncType
        self.vectorClock = vectorClock
        self.changes = changes
        self.cursor = cursor
        self.filters = filters
    }
}

/// Sync response from server to client
public struct SyncResponse: Codable {
    public let protocolVersion: String
    public let syncType: SyncType
    public let changes: [SyncChange]
    public let conflicts: [ConflictInfo]
    public let vectorClock: VectorClock
    public let cursor: String?
    public let syncStats: SyncStats
}

/// Types of synchronization
public enum SyncType: String, Codable {
    case full = "full"
    case delta = "delta"
    case entities = "entities"
    case relationships = "relationships"
}

/// Individual change in sync
public struct SyncChange: Codable {
    public let changeType: ChangeType
    public let entity: EntityChange?
    public let relationships: [RelationshipChange]
    
    public enum ChangeType: String, Codable {
        case create = "create"
        case update = "update"
        case delete = "delete"
    }
}
```

#### VectorClock.swift
```swift
import Foundation

/// Vector clock for distributed state tracking
public struct VectorClock: Codable, Equatable {
    public var clocks: [String: String]
    
    public init(clocks: [String: String] = [:]) {
        self.clocks = clocks
    }
    
    /// Increment clock for given node
    public mutating func increment(for nodeId: String) {
        let current = Int(clocks[nodeId] ?? "0") ?? 0
        clocks[nodeId] = String(current + 1)
    }
    
    /// Check if this clock happens before another
    public func happensBefore(_ other: VectorClock) -> Bool {
        for (nodeId, value) in clocks {
            guard let otherValue = other.clocks[nodeId],
                  let thisTime = Int(value),
                  let otherTime = Int(otherValue) else {
                continue
            }
            if thisTime > otherTime {
                return false
            }
        }
        return true
    }
    
    /// Check if clocks are concurrent (neither happens before the other)
    public func isConcurrent(with other: VectorClock) -> Bool {
        return !happensBefore(other) && !other.happensBefore(self)
    }
    
    /// Merge with another clock, taking maximum of each component
    public mutating func merge(with other: VectorClock) {
        for (nodeId, value) in other.clocks {
            if let currentValue = clocks[nodeId],
               let current = Int(currentValue),
               let other = Int(value) {
                clocks[nodeId] = String(max(current, other))
            } else if let other = Int(value) {
                clocks[nodeId] = value
            }
        }
    }
}
```

#### ConflictResolver.swift
```swift
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
            return local.updatedAt > remote.updatedAt ? local : remote
            
        case .firstWriteWins:
            return local.createdAt < remote.createdAt ? local : remote
            
        case .merge:
            return mergeEntities(local: local, remote: remote)
            
        case .manual:
            // In production, this would trigger user intervention
            return local
        }
    }
    
    private func mergeEntities(local: Entity, remote: Entity) -> Entity {
        // Merge content dictionaries
        var mergedContent = local.content
        for (key, value) in remote.content {
            if mergedContent[key] == nil {
                mergedContent[key] = value
            }
        }
        
        // Create new version with both as parents
        let newVersion = UUID().uuidString
        var parentVersions = [local.version, remote.version]
        parentVersions.append(contentsOf: local.parentVersions)
        parentVersions.append(contentsOf: remote.parentVersions)
        
        return Entity(
            id: local.id,
            version: newVersion,
            entityType: local.entityType,
            name: local.name,
            content: mergedContent,
            sourceType: local.sourceType,
            userId: local.userId,
            parentVersions: Array(Set(parentVersions)),
            createdAt: min(local.createdAt, remote.createdAt),
            updatedAt: Date()
        )
    }
}
```

### 3. Graph Module

#### GraphOperations.swift
```swift
import Foundation

/// Operations for manipulating the knowledge graph
public class GraphOperations {
    private var entities: [String: Entity] = [:]
    private var relationships: [String: EntityRelationship] = [:]
    
    public init() {}
    
    /// Add entity to graph
    public func addEntity(_ entity: Entity) {
        entities[entity.id] = entity
    }
    
    /// Add relationship to graph
    public func addRelationship(_ relationship: EntityRelationship) {
        relationships[relationship.id] = relationship
    }
    
    /// Get entity by ID
    public func getEntity(id: String) -> Entity? {
        return entities[id]
    }
    
    /// Get all relationships for an entity
    public func getRelationships(for entityId: String) -> [EntityRelationship] {
        return relationships.values.filter { relationship in
            relationship.fromEntityId == entityId || relationship.toEntityId == entityId
        }
    }
    
    /// Get entities of specific type
    public func getEntities(ofType type: EntityType) -> [Entity] {
        return entities.values.filter { $0.entityType == type }
    }
    
    /// Find path between two entities
    public func findPath(from: String, to: String) -> [String]? {
        var visited = Set<String>()
        var queue = [(from, [from])]
        
        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            
            if current == to {
                return path
            }
            
            if visited.contains(current) {
                continue
            }
            visited.insert(current)
            
            for relationship in getRelationships(for: current) {
                let next = relationship.fromEntityId == current ? 
                    relationship.toEntityId : relationship.fromEntityId
                if !visited.contains(next) {
                    queue.append((next, path + [next]))
                }
            }
        }
        
        return nil
    }
}
```

### 4. MCP Module

#### MCPTool.swift
```swift
import Foundation

/// MCP tool definition
public struct MCPTool: Codable {
    public let name: String
    public let description: String
    public let inputSchema: [String: Any]?
    public let outputSchema: [String: Any]?
    
    public init(
        name: String,
        description: String,
        inputSchema: [String: Any]? = nil,
        outputSchema: [String: Any]? = nil
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.outputSchema = outputSchema
    }
}

/// MCP tool execution result
public struct MCPToolResult: Codable {
    public let success: Bool
    public let output: AnyCodable?
    public let error: String?
}
```

#### ToolDefinitions.swift
```swift
import Foundation

/// Standard MCP tools for the knowledge graph
public struct MCPTools {
    
    public static let listEntities = MCPTool(
        name: "list_entities",
        description: "List all entities in the knowledge graph",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_type": ["type": "string"]
            ]
        ]
    )
    
    public static let getEntity = MCPTool(
        name: "get_entity",
        description: "Get a specific entity by ID",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_id": ["type": "string"]
            ],
            "required": ["entity_id"]
        ]
    )
    
    public static let createEntity = MCPTool(
        name: "create_entity",
        description: "Create a new entity",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_type": ["type": "string"],
                "name": ["type": "string"],
                "content": ["type": "object"]
            ],
            "required": ["entity_type", "name"]
        ]
    )
    
    public static let updateEntity = MCPTool(
        name: "update_entity",
        description: "Update an existing entity",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_id": ["type": "string"],
                "updates": ["type": "object"]
            ],
            "required": ["entity_id", "updates"]
        ]
    )
    
    public static let deleteEntity = MCPTool(
        name: "delete_entity",
        description: "Delete an entity",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_id": ["type": "string"]
            ],
            "required": ["entity_id"]
        ]
    )
    
    public static let listRelationships = MCPTool(
        name: "list_relationships",
        description: "List relationships for an entity",
        inputSchema: [
            "type": "object",
            "properties": [
                "entity_id": ["type": "string"]
            ],
            "required": ["entity_id"]
        ]
    )
    
    public static let createRelationship = MCPTool(
        name: "create_relationship",
        description: "Create a relationship between entities",
        inputSchema: [
            "type": "object",
            "properties": [
                "from_entity_id": ["type": "string"],
                "to_entity_id": ["type": "string"],
                "relationship_type": ["type": "string"]
            ],
            "required": ["from_entity_id", "to_entity_id", "relationship_type"]
        ]
    )
    
    public static let allTools: [MCPTool] = [
        listEntities,
        getEntity,
        createEntity,
        updateEntity,
        deleteEntity,
        listRelationships,
        createRelationship
    ]
}
```

### 5. Utils Module

#### JSONCoding.swift
```swift
import Foundation

/// Type-erased Codable wrapper for heterogeneous JSON
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode value"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Cannot encode value"
                )
            )
        }
    }
}

extension AnyCodable: Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case (is NSNull, is NSNull):
            return true
        default:
            return false
        }
    }
}
```

## Testing Plan

### Unit Tests

#### Model Tests
- Entity serialization/deserialization
- Relationship serialization/deserialization
- EntityType and RelationshipType enumeration coverage
- AnyCodable encoding/decoding with various types

#### Sync Tests
- VectorClock operations (increment, merge, comparison)
- Conflict resolution strategies
- SyncRequest/Response serialization
- SyncChange construction

#### Graph Tests
- Entity addition and retrieval
- Relationship management
- Path finding algorithms
- Type-based filtering

#### MCP Tests
- Tool definition validation
- Input schema validation
- Result serialization

### Integration Tests
- Full sync protocol flow simulation
- Conflict resolution scenarios
- Graph traversal with complex relationships
- MCP tool execution simulation

## Package.swift Configuration
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Inbetweenies",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "Inbetweenies",
            targets: ["Inbetweenies"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Inbetweenies",
            dependencies: []),
        .testTarget(
            name: "InbetweeniesTests",
            dependencies: ["Inbetweenies"]),
    ]
)
```

## Success Metrics
1. All models properly encode/decode JSON
2. Vector clock operations work correctly
3. Conflict resolution handles all strategies
4. Graph operations perform efficiently
5. 100% test coverage for public API
6. Zero external dependencies
7. Clean API documentation