# Swift Port Architecture Plan for The Goodies

## Overview
This document outlines the architecture for porting the Python-based "The Goodies" distributed MCP knowledge graph system to Swift, creating two packages (Inbetweenies and Wildthing) and a test app (Bertha).

## System Components

### 1. Inbetweenies Package (Protocol Layer)
Swift protocol package providing the shared synchronization protocol and data models.

#### Core Components:
- **Models**: Entity and relationship models for the knowledge graph
- **Sync Protocol**: Synchronization protocol definitions and handlers
- **Graph Operations**: Graph traversal and manipulation utilities
- **MCP Tools**: Model Context Protocol tool definitions

#### Key Classes/Protocols:
- `Entity`: Generic entity model (homes, rooms, devices, etc.)
- `EntityRelationship`: Edge model for graph connections
- `SyncProtocol`: Protocol for client-server synchronization
- `VectorClock`: Distributed state tracking
- `ConflictResolver`: Conflict resolution strategies

### 2. Wildthing Package (Client Layer)
Swift client package implementing the synchronization client with local storage.

#### Core Components:
- **Client**: Main client class for server communication
- **Local Storage**: Core Data or SQLite for offline operation
- **Sync Engine**: Synchronization logic and conflict handling
- **Graph Storage**: Local graph operations and caching
- **Auth Manager**: Authentication and token management

#### Key Classes:
- `WildthingClient`: Main client interface
- `SyncEngine`: Handles sync operations with server
- `LocalGraphStorage`: Persistent local storage
- `LocalGraphOperations`: Offline graph manipulation
- `AuthManager`: JWT and authentication handling

### 3. Bertha Test App
SwiftUI test application demonstrating package functionality.

#### Features:
- Connection management UI
- Entity browsing and editing
- Sync status monitoring
- Graph visualization
- MCP tool execution

## Technical Stack

### Swift/iOS Technologies:
- **Swift 6.1**: Modern Swift with async/await
- **SwiftUI**: User interface framework
- **Combine**: Reactive programming for data flow
- **Core Data/SQLite**: Local persistence
- **URLSession**: Network communication
- **Swift Package Manager**: Dependency management

### Networking:
- **REST API**: HTTP/HTTPS communication with FunkyGibbon server
- **JSON**: Data serialization format
- **WebSocket**: Real-time updates (future enhancement)

### Testing:
- **XCTest**: Unit and integration testing
- **Quick/Nimble**: BDD-style testing (optional)
- **Mock Server**: Local test server for integration tests

## Data Models

### Entity Model:
```swift
struct Entity: Codable, Identifiable {
    let id: String
    let version: String
    let entityType: EntityType
    let name: String
    let content: [String: Any]
    let sourceType: SourceType
    let userId: String?
    let parentVersions: [String]
    let createdAt: Date
    let updatedAt: Date
}

enum EntityType: String, CaseIterable, Codable {
    case home, room, device, zone, door, window
    case procedure, manual, note, schedule
    case automation, app
}

enum SourceType: String, Codable {
    case homekit, matter, manual, imported, generated
}
```

### Relationship Model:
```swift
struct EntityRelationship: Codable, Identifiable {
    let id: String
    let fromEntityId: String
    let fromEntityVersion: String
    let toEntityId: String
    let toEntityVersion: String
    let relationshipType: RelationshipType
    let properties: [String: Any]
    let userId: String?
    let createdAt: Date
    let updatedAt: Date
}

enum RelationshipType: String, CaseIterable, Codable {
    case locatedIn = "located_in"
    case controls, connectsTo = "connects_to"
    case partOf = "part_of", manages
    case documentedBy = "documented_by"
    case procedureFor = "procedure_for"
    case triggeredBy = "triggered_by"
    case dependsOn = "depends_on"
    case containedIn = "contained_in"
    case monitors, automates
    case controlledByApp = "controlled_by_app"
    case hasBlob = "has_blob"
}
```

### Sync Protocol Models:
```swift
struct SyncRequest: Codable {
    let protocolVersion: String = "inbetweenies-v2"
    let deviceId: String
    let userId: String
    let syncType: SyncType
    let vectorClock: VectorClock
    let changes: [SyncChange]
    let cursor: String?
    let filters: SyncFilters?
}

struct SyncResponse: Codable {
    let protocolVersion: String
    let syncType: SyncType
    let changes: [SyncChange]
    let conflicts: [ConflictInfo]
    let vectorClock: VectorClock
    let cursor: String?
    let syncStats: SyncStats
}

enum SyncType: String, Codable {
    case full, delta, entities, relationships
}
```

## Implementation Phases

### Phase 1: Inbetweenies Protocol Package
1. Define data models (Entity, Relationship)
2. Implement sync protocol structures
3. Create graph operation utilities
4. Add MCP tool definitions
5. Write comprehensive unit tests

### Phase 2: Wildthing Client Package
1. Implement client initialization
2. Add authentication manager
3. Create sync engine
4. Implement local storage (Core Data/SQLite)
5. Add offline queue management
6. Create conflict resolution
7. Write integration tests

### Phase 3: Bertha Test App
1. Create SwiftUI interface
2. Add connection management
3. Implement entity browser
4. Add sync status monitoring
5. Create debug tools
6. Test end-to-end functionality

### Phase 4: Integration Testing
1. Set up test FunkyGibbon server
2. Test full sync scenarios
3. Test offline operation
4. Test conflict resolution
5. Performance testing
6. Memory leak testing

## API Design

### Wildthing Client API:
```swift
class WildthingClient {
    // Connection
    func connect(serverURL: URL, authToken: String?) async throws
    func disconnect() async
    
    // Authentication
    func authenticate(clientId: String, password: String) async throws -> String
    
    // Synchronization
    func sync() async throws -> SyncResult
    func fullSync() async throws -> SyncResult
    
    // Local Operations
    func createEntity(_ entity: Entity) async throws
    func updateEntity(_ entity: Entity) async throws
    func deleteEntity(id: String) async throws
    func getEntity(id: String) async throws -> Entity?
    func listEntities(type: EntityType?) async throws -> [Entity]
    
    // Relationships
    func createRelationship(_ relationship: EntityRelationship) async throws
    func deleteRelationship(id: String) async throws
    func getRelationships(for entityId: String) async throws -> [EntityRelationship]
    
    // MCP Tools
    func executeTool(_ tool: MCPTool, parameters: [String: Any]) async throws -> Any
}
```

## Error Handling

### Error Types:
```swift
enum WildthingError: LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case syncFailed(String)
    case conflictResolutionFailed(String)
    case storageError(String)
    case networkError(String)
    case invalidData(String)
    case serverError(Int, String)
}
```

## Testing Strategy

### Unit Tests:
- Model serialization/deserialization
- Graph operations
- Conflict resolution logic
- Vector clock operations
- Local storage operations

### Integration Tests:
- Client-server communication
- Full sync scenarios
- Delta sync scenarios
- Offline queue processing
- Conflict resolution scenarios

### End-to-End Tests:
- Complete user workflows
- Multi-device synchronization
- Network failure recovery
- Performance benchmarks

## Security Considerations

1. **Authentication**: JWT token-based auth with secure storage
2. **Data Encryption**: TLS for network communication
3. **Local Storage**: Encrypted Core Data/SQLite database
4. **Token Management**: Secure keychain storage for tokens
5. **API Key Protection**: Environment-based configuration

## Performance Targets

1. **Sync Performance**: < 2 seconds for delta sync of 100 entities
2. **Local Operations**: < 100ms for CRUD operations
3. **Memory Usage**: < 50MB for 1000 entities
4. **Startup Time**: < 1 second to initialize client
5. **Offline Queue**: Support 1000+ pending operations

## Dependencies

### Inbetweenies:
- No external dependencies (pure Swift)

### Wildthing:
- Inbetweenies (local package)
- SQLite.swift or Core Data
- Swift Crypto (for JWT handling)

### Bertha:
- Wildthing (local package)
- Inbetweenies (transitive)
- SwiftUI (system framework)

## Migration Path

For existing Python clients:
1. Data export from Python SQLite
2. Import into Swift Core Data/SQLite
3. Vector clock synchronization
4. Gradual migration support

## Future Enhancements

1. **WebSocket Support**: Real-time updates from server
2. **GraphQL API**: Alternative to REST
3. **SwiftData**: Migration from Core Data
4. **Widget Support**: iOS widgets for monitoring
5. **watchOS App**: Apple Watch companion
6. **macOS Catalyst**: Desktop application
7. **CloudKit Sync**: iCloud backup/sync
8. **HomeKit Integration**: Direct HomeKit access

## Success Criteria

1. All unit tests passing (100% of Python test coverage)
2. Successful sync with FunkyGibbon server
3. Offline operation with queue management
4. Conflict resolution working correctly
5. Memory and performance targets met
6. Bertha app functional on iOS device
7. Documentation complete

## Timeline

- Week 1: Inbetweenies package implementation
- Week 2: Wildthing package core functionality
- Week 3: Bertha app and integration testing
- Week 4: Bug fixes, optimization, documentation

## Risks and Mitigations

1. **Risk**: Protocol incompatibility with Python server
   - **Mitigation**: Extensive protocol testing, version negotiation

2. **Risk**: Core Data complexity for graph storage
   - **Mitigation**: Consider SQLite.swift as alternative

3. **Risk**: Performance issues with large graphs
   - **Mitigation**: Implement pagination, lazy loading

4. **Risk**: Swift Codable limitations with dynamic JSON
   - **Mitigation**: Custom coding strategies, AnyCodable wrapper

5. **Risk**: Testing server availability
   - **Mitigation**: Mock server implementation for tests