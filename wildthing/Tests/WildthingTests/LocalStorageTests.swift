import XCTest
@testable import Wildthing
@testable import Inbetweenies

final class LocalStorageTests: XCTestCase {
    
    var storage: LocalStorage!
    var configuration: Configuration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use in-memory database for tests
        configuration = Configuration(
            databasePath: ":memory:",
            autoSync: false
        )
        
        storage = try LocalStorage(configuration: configuration)
    }
    
    override func tearDown() async throws {
        storage = nil
        configuration = nil
        try await super.tearDown()
    }
    
    // MARK: - Entity Tests
    
    func testCreateEntity() async throws {
        let entity = Entity(
            id: "test-1",
            version: "v1",
            entityType: .device,
            name: "Test Device",
            content: ["status": AnyCodable("active")],
            sourceType: .manual
        )
        
        try await storage.createEntity(entity)
        
        let retrieved = try await storage.getEntity(id: "test-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, entity.id)
        XCTAssertEqual(retrieved?.name, entity.name)
        XCTAssertEqual(retrieved?.entityType, entity.entityType)
    }
    
    func testUpdateEntity() async throws {
        let entity = Entity(
            id: "test-1",
            version: "v1",
            entityType: .device,
            name: "Original Name"
        )
        
        try await storage.createEntity(entity)
        
        let updated = Entity(
            id: "test-1",
            version: "v2",
            entityType: .device,
            name: "Updated Name"
        )
        
        try await storage.updateEntity(updated)
        
        let retrieved = try await storage.getEntity(id: "test-1")
        XCTAssertEqual(retrieved?.name, "Updated Name")
    }
    
    func testDeleteEntity() async throws {
        let entity = Entity(
            id: "test-1",
            version: "v1",
            entityType: .device,
            name: "Test Device"
        )
        
        try await storage.createEntity(entity)
        try await storage.deleteEntity(id: "test-1")
        
        // Entity should be marked for deletion, not actually deleted yet
        let changes = try await storage.getPendingChanges()
        XCTAssertTrue(changes.contains { $0.changeType == .delete && $0.entity?.id == "test-1" })
    }
    
    func testListEntities() async throws {
        let entities = [
            Entity(id: "1", version: "v1", entityType: .device, name: "Device 1"),
            Entity(id: "2", version: "v1", entityType: .room, name: "Room 1"),
            Entity(id: "3", version: "v1", entityType: .device, name: "Device 2")
        ]
        
        for entity in entities {
            try await storage.createEntity(entity)
        }
        
        let allEntities = try await storage.listEntities()
        XCTAssertEqual(allEntities.count, 3)
        
        let devices = try await storage.listEntities(type: .device)
        XCTAssertEqual(devices.count, 2)
        
        let rooms = try await storage.listEntities(type: .room)
        XCTAssertEqual(rooms.count, 1)
    }
    
    // MARK: - Relationship Tests
    
    func testCreateRelationship() async throws {
        let relationship = EntityRelationship(
            id: "rel-1",
            fromEntityId: "entity-1",
            fromEntityVersion: "v1",
            toEntityId: "entity-2",
            toEntityVersion: "v1",
            relationshipType: .controls
        )
        
        try await storage.createRelationship(relationship)
        
        let retrieved = try await storage.getRelationships(for: "entity-1")
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved.first?.id, "rel-1")
    }
    
    func testGetRelationships() async throws {
        let relationships = [
            EntityRelationship(
                id: "rel-1",
                fromEntityId: "entity-1",
                fromEntityVersion: "v1",
                toEntityId: "entity-2",
                toEntityVersion: "v1",
                relationshipType: .controls
            ),
            EntityRelationship(
                id: "rel-2",
                fromEntityId: "entity-2",
                fromEntityVersion: "v1",
                toEntityId: "entity-3",
                toEntityVersion: "v1",
                relationshipType: .locatedIn
            ),
            EntityRelationship(
                id: "rel-3",
                fromEntityId: "entity-3",
                fromEntityVersion: "v1",
                toEntityId: "entity-1",
                toEntityVersion: "v1",
                relationshipType: .dependsOn
            )
        ]
        
        for relationship in relationships {
            try await storage.createRelationship(relationship)
        }
        
        let entity1Relationships = try await storage.getRelationships(for: "entity-1")
        XCTAssertEqual(entity1Relationships.count, 2) // As from and to
        
        let entity2Relationships = try await storage.getRelationships(for: "entity-2")
        XCTAssertEqual(entity2Relationships.count, 2)
    }
    
    // MARK: - Sync Tests
    
    func testPendingChanges() async throws {
        let entity = Entity(
            id: "test-1",
            version: "v1",
            entityType: .device,
            name: "Test Device"
        )
        
        try await storage.createEntity(entity)
        
        let changes = try await storage.getPendingChanges()
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.changeType, .create)
        XCTAssertEqual(changes.first?.entity?.id, "test-1")
    }
    
    func testClearPendingChanges() async throws {
        let entity = Entity(
            id: "test-1",
            version: "v1",
            entityType: .device,
            name: "Test Device"
        )
        
        try await storage.createEntity(entity)
        
        var changes = try await storage.getPendingChanges()
        XCTAssertEqual(changes.count, 1)
        
        try await storage.clearPendingChanges()
        
        changes = try await storage.getPendingChanges()
        XCTAssertEqual(changes.count, 0)
    }
    
    func testSyncMetadata() async throws {
        var vectorClock = VectorClock()
        vectorClock.increment(for: "node1")
        vectorClock.increment(for: "node2")
        
        try await storage.updateSyncMetadata(vectorClock: vectorClock, cursor: "cursor-123")
        
        let metadata = try await storage.getSyncMetadata()
        XCTAssertEqual(metadata.vectorClock.clocks["node1"], "1")
        XCTAssertEqual(metadata.vectorClock.clocks["node2"], "1")
        XCTAssertEqual(metadata.cursor, "cursor-123")
    }
    
    // MARK: - Performance Tests
    
    func testBulkInsertPerformance() async throws {
        let startTime = Date()
        
        for i in 1...100 {
            let entity = Entity(
                id: "entity-\(i)",
                version: "v1",
                entityType: .device,
                name: "Device \(i)"
            )
            try await storage.createEntity(entity)
        }
        
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 5.0, "Bulk insert of 100 entities should complete within 5 seconds")
        
        let entities = try await storage.listEntities()
        XCTAssertEqual(entities.count, 100)
    }
}