import XCTest
@testable import Inbetweenies

final class EntityTests: XCTestCase {
    
    func testEntityInitialization() {
        let entity = Entity(
            id: "test-id",
            version: "v1",
            entityType: .device,
            name: "Test Device",
            content: ["key": AnyCodable("value")],
            sourceType: .manual,
            userId: "user-1",
            parentVersions: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(entity.id, "test-id")
        XCTAssertEqual(entity.version, "v1")
        XCTAssertEqual(entity.entityType, .device)
        XCTAssertEqual(entity.name, "Test Device")
        XCTAssertEqual(entity.content["key"]?.stringValue, "value")
        XCTAssertEqual(entity.sourceType, .manual)
        XCTAssertEqual(entity.userId, "user-1")
        XCTAssertTrue(entity.parentVersions.isEmpty)
    }
    
    func testEntitySerialization() throws {
        let date = Date()
        let entity = Entity(
            id: "test-id",
            version: "v1",
            entityType: .device,
            name: "Test Device",
            content: [
                "string": AnyCodable("value"),
                "number": AnyCodable(42),
                "bool": AnyCodable(true)
            ],
            createdAt: date,
            updatedAt: date
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let encoded = try encoder.encode(entity)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Entity.self, from: encoded)
        
        XCTAssertEqual(entity.id, decoded.id)
        XCTAssertEqual(entity.version, decoded.version)
        XCTAssertEqual(entity.name, decoded.name)
        XCTAssertEqual(entity.entityType, decoded.entityType)
        XCTAssertEqual(decoded.content["string"]?.stringValue, "value")
        XCTAssertEqual(decoded.content["number"]?.intValue, 42)
        XCTAssertEqual(decoded.content["bool"]?.boolValue, true)
    }
    
    func testEntityEquality() {
        let entity1 = Entity(id: "1", version: "v1", entityType: .device, name: "Device")
        let entity2 = Entity(id: "1", version: "v1", entityType: .device, name: "Device")
        let entity3 = Entity(id: "1", version: "v2", entityType: .device, name: "Device")
        let entity4 = Entity(id: "2", version: "v1", entityType: .device, name: "Device")
        
        XCTAssertEqual(entity1, entity2)
        XCTAssertNotEqual(entity1, entity3) // Different version
        XCTAssertNotEqual(entity1, entity4) // Different ID
    }
    
    func testEntityTypes() {
        XCTAssertEqual(EntityType.allCases.count, 12)
        XCTAssertTrue(EntityType.allCases.contains(.home))
        XCTAssertTrue(EntityType.allCases.contains(.device))
        XCTAssertTrue(EntityType.allCases.contains(.automation))
    }
    
    func testSourceTypes() {
        let entity1 = Entity(id: "1", version: "v1", entityType: .device, name: "Device", sourceType: .homekit)
        let entity2 = Entity(id: "2", version: "v1", entityType: .device, name: "Device", sourceType: .matter)
        
        XCTAssertEqual(entity1.sourceType, .homekit)
        XCTAssertEqual(entity2.sourceType, .matter)
    }
    
    func testEntityToEntityChange() {
        let entity = Entity(
            id: "test-id",
            version: "v1",
            entityType: .device,
            name: "Test Device",
            content: ["key": AnyCodable("value")],
            sourceType: .manual,
            userId: "user-1"
        )
        
        let change = entity.toEntityChange()
        
        XCTAssertEqual(change.id, entity.id)
        XCTAssertEqual(change.version, entity.version)
        XCTAssertEqual(change.entityType, entity.entityType.rawValue)
        XCTAssertEqual(change.name, entity.name)
        XCTAssertEqual(change.sourceType, entity.sourceType.rawValue)
    }
}