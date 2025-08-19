import XCTest
@testable import Wildthing
@testable import Inbetweenies

final class SyncEngineTests: XCTestCase {
    
    var syncEngine: SyncEngine!
    var localStorage: LocalStorage!
    var authManager: AuthManager!
    var configuration: Configuration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        configuration = Configuration(
            serverURL: URL(string: "https://test.example.com"),
            databasePath: ":memory:",
            autoSync: false
        )
        
        localStorage = try LocalStorage(configuration: configuration)
        authManager = AuthManager(configuration: configuration)
        
        syncEngine = SyncEngine(
            deviceId: "test-device",
            localStorage: localStorage,
            authManager: authManager,
            configuration: configuration
        )
    }
    
    override func tearDown() async throws {
        syncEngine = nil
        localStorage = nil
        authManager = nil
        configuration = nil
        try await super.tearDown()
    }
    
    func testSyncEngineInitialization() {
        XCTAssertNotNil(syncEngine)
        XCTAssertFalse(syncEngine.isSyncInProgress)
    }
    
    func testPendingChangesPreparation() async throws {
        // Create some local changes
        let entity1 = Entity(
            id: "entity-1",
            version: "v1",
            entityType: .device,
            name: "Device 1"
        )
        
        let entity2 = Entity(
            id: "entity-2",
            version: "v1",
            entityType: .room,
            name: "Room 1"
        )
        
        try await localStorage.createEntity(entity1)
        try await localStorage.createEntity(entity2)
        
        let relationship = EntityRelationship(
            id: "rel-1",
            fromEntityId: "entity-1",
            fromEntityVersion: "v1",
            toEntityId: "entity-2",
            toEntityVersion: "v1",
            relationshipType: .locatedIn
        )
        
        try await localStorage.createRelationship(relationship)
        
        // Verify pending changes
        let changes = try await localStorage.getPendingChanges()
        XCTAssertEqual(changes.count, 3) // 2 entities + 1 relationship
        
        // Verify change types
        let entityChanges = changes.filter { $0.entity != nil }
        XCTAssertEqual(entityChanges.count, 2)
        
        let relationshipChanges = changes.filter { !$0.relationships.isEmpty }
        XCTAssertEqual(relationshipChanges.count, 1)
    }
    
    func testConflictResolution() async throws {
        // Create local entity
        let localEntity = Entity(
            id: "conflict-1",
            version: "v1",
            entityType: .device,
            name: "Local Name",
            content: ["local": AnyCodable(true)],
            updatedAt: Date()
        )
        
        try await localStorage.createEntity(localEntity)
        
        // Simulate remote entity with conflict
        let remoteEntity = Entity(
            id: "conflict-1",
            version: "v2",
            entityType: .device,
            name: "Remote Name",
            content: ["remote": AnyCodable(true)],
            updatedAt: Date().addingTimeInterval(60) // Remote is newer
        )
        
        // Test conflict resolution
        let resolver = ConflictResolver()
        let resolved = resolver.resolve(
            local: localEntity,
            remote: remoteEntity,
            strategy: .lastWriteWins
        )
        
        XCTAssertEqual(resolved.name, "Remote Name") // Remote wins (newer)
    }
    
    func testStopSync() {
        XCTAssertFalse(syncEngine.isSyncInProgress)
        
        syncEngine.stop()
        
        XCTAssertFalse(syncEngine.isSyncInProgress)
    }
}