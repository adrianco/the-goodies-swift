# Testing Strategy for The Goodies Swift Port

## Overview
Comprehensive testing strategy covering unit tests, integration tests, and end-to-end testing for the Swift implementation of The Goodies distributed MCP knowledge graph system.

## Testing Framework

### Tools and Technologies
- **XCTest**: Apple's native testing framework
- **Quick/Nimble**: BDD-style testing (optional)
- **XCUITest**: UI automation testing
- **MockingBird**: Swift mocking framework
- **OHHTTPStubs**: Network request stubbing
- **Core Data Test Stack**: In-memory database for testing

## Test Coverage Goals

### Overall Coverage Targets
- **Inbetweenies Package**: 95% code coverage
- **Wildthing Package**: 85% code coverage
- **Bertha App**: 70% code coverage
- **Critical Paths**: 100% coverage

### Critical Paths
1. Authentication flow
2. Sync protocol implementation
3. Conflict resolution
4. Local storage operations
5. Network error handling

## Test Categories

### 1. Unit Tests

#### Inbetweenies Package Tests

##### Model Tests
```swift
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
        XCTAssertEqual(entity.entityType, .device)
        XCTAssertEqual(entity.name, "Test Device")
    }
    
    func testEntitySerialization() throws {
        let entity = Entity(
            id: "test-id",
            version: "v1",
            entityType: .device,
            name: "Test Device"
        )
        
        let encoded = try JSONEncoder().encode(entity)
        let decoded = try JSONDecoder().decode(Entity.self, from: encoded)
        
        XCTAssertEqual(entity.id, decoded.id)
        XCTAssertEqual(entity.name, decoded.name)
    }
    
    func testEntityEquality() {
        let entity1 = Entity(id: "1", version: "v1", entityType: .device, name: "Device")
        let entity2 = Entity(id: "1", version: "v1", entityType: .device, name: "Device")
        let entity3 = Entity(id: "2", version: "v1", entityType: .device, name: "Device")
        
        XCTAssertEqual(entity1, entity2)
        XCTAssertNotEqual(entity1, entity3)
    }
}
```

##### Vector Clock Tests
```swift
import XCTest
@testable import Inbetweenies

final class VectorClockTests: XCTestCase {
    
    func testVectorClockIncrement() {
        var clock = VectorClock()
        clock.increment(for: "node1")
        clock.increment(for: "node1")
        clock.increment(for: "node2")
        
        XCTAssertEqual(clock.clocks["node1"], "2")
        XCTAssertEqual(clock.clocks["node2"], "1")
    }
    
    func testHappensBefore() {
        var clock1 = VectorClock(clocks: ["node1": "1", "node2": "2"])
        var clock2 = VectorClock(clocks: ["node1": "2", "node2": "2"])
        
        XCTAssertTrue(clock1.happensBefore(clock2))
        XCTAssertFalse(clock2.happensBefore(clock1))
    }
    
    func testConcurrency() {
        let clock1 = VectorClock(clocks: ["node1": "2", "node2": "1"])
        let clock2 = VectorClock(clocks: ["node1": "1", "node2": "2"])
        
        XCTAssertTrue(clock1.isConcurrent(with: clock2))
    }
    
    func testMerge() {
        var clock1 = VectorClock(clocks: ["node1": "2", "node2": "1"])
        let clock2 = VectorClock(clocks: ["node1": "1", "node2": "3", "node3": "1"])
        
        clock1.merge(with: clock2)
        
        XCTAssertEqual(clock1.clocks["node1"], "2")
        XCTAssertEqual(clock1.clocks["node2"], "3")
        XCTAssertEqual(clock1.clocks["node3"], "1")
    }
}
```

##### Conflict Resolution Tests
```swift
import XCTest
@testable import Inbetweenies

final class ConflictResolverTests: XCTestCase {
    
    let resolver = ConflictResolver()
    
    func testLastWriteWins() {
        let olderEntity = Entity(
            id: "1",
            version: "v1",
            entityType: .device,
            name: "Old Name",
            updatedAt: Date(timeIntervalSinceNow: -100)
        )
        
        let newerEntity = Entity(
            id: "1",
            version: "v2",
            entityType: .device,
            name: "New Name",
            updatedAt: Date()
        )
        
        let resolved = resolver.resolve(
            local: olderEntity,
            remote: newerEntity,
            strategy: .lastWriteWins
        )
        
        XCTAssertEqual(resolved.name, "New Name")
    }
    
    func testMergeStrategy() {
        let localEntity = Entity(
            id: "1",
            version: "v1",
            entityType: .device,
            name: "Device",
            content: ["prop1": AnyCodable("value1")]
        )
        
        let remoteEntity = Entity(
            id: "1",
            version: "v2",
            entityType: .device,
            name: "Device",
            content: ["prop2": AnyCodable("value2")]
        )
        
        let resolved = resolver.resolve(
            local: localEntity,
            remote: remoteEntity,
            strategy: .merge
        )
        
        XCTAssertNotNil(resolved.content["prop1"])
        XCTAssertNotNil(resolved.content["prop2"])
        XCTAssertEqual(resolved.parentVersions.count, 2)
    }
}
```

#### Wildthing Package Tests

##### Auth Manager Tests
```swift
import XCTest
@testable import Wildthing

final class AuthManagerTests: XCTestCase {
    
    var authManager: AuthManager!
    
    override func setUp() {
        super.setUp()
        authManager = AuthManager(configuration: .default)
    }
    
    func testTokenStorage() async throws {
        let testToken = "test-jwt-token"
        
        try await authManager.setToken(testToken)
        let retrievedToken = authManager.getToken()
        
        XCTAssertEqual(retrievedToken, testToken)
    }
    
    func testTokenClearance() async throws {
        try await authManager.setToken("test-token")
        await authManager.clearToken()
        
        XCTAssertNil(authManager.getToken())
    }
}
```

##### Sync Engine Tests
```swift
import XCTest
@testable import Wildthing
@testable import Inbetweenies

final class SyncEngineTests: XCTestCase {
    
    var syncEngine: SyncEngine!
    var mockStorage: MockLocalStorage!
    var mockAPIClient: MockAPIClient!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockLocalStorage()
        mockAPIClient = MockAPIClient()
        
        syncEngine = SyncEngine(
            deviceId: "test-device",
            localStorage: mockStorage,
            apiClient: mockAPIClient,
            authManager: MockAuthManager()
        )
    }
    
    func testDeltaSync() async throws {
        // Setup mock pending changes
        let pendingEntity = Entity(
            id: "1",
            version: "v1",
            entityType: .device,
            name: "Test Device"
        )
        
        mockStorage.pendingChanges = [
            SyncChange(
                changeType: .create,
                entity: pendingEntity.toEntityChange(),
                relationships: []
            )
        ]
        
        // Setup mock response
        mockAPIClient.syncResponse = SyncResponse(
            protocolVersion: "inbetweenies-v2",
            syncType: .delta,
            changes: [],
            conflicts: [],
            vectorClock: VectorClock(),
            cursor: nil,
            syncStats: SyncStats(
                entitiesSynced: 1,
                relationshipsSynced: 0,
                conflictsResolved: 0,
                durationMs: 100
            )
        )
        
        let result = try await syncEngine.sync()
        
        XCTAssertEqual(result.entitiesSynced, 1)
        XCTAssertTrue(mockStorage.pendingChangesCleared)
    }
}
```

### 2. Integration Tests

#### Client-Server Integration
```swift
import XCTest
@testable import Wildthing

final class ClientServerIntegrationTests: XCTestCase {
    
    var client: WildthingClient!
    var testServer: TestServer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Start test server
        testServer = TestServer()
        try await testServer.start(port: 8080)
        
        // Initialize client
        client = WildthingClient(configuration: .default)
    }
    
    override func tearDown() async throws {
        await testServer.stop()
        try await super.tearDown()
    }
    
    func testFullSyncFlow() async throws {
        // Connect to test server
        try await client.connect(
            serverURL: URL(string: "http://localhost:8080")!,
            clientId: "test-client",
            password: "test-password"
        )
        
        // Create entity
        let entity = Entity(
            id: UUID().uuidString,
            version: UUID().uuidString,
            entityType: .device,
            name: "Test Device"
        )
        
        try await client.createEntity(entity)
        
        // Sync
        let syncResult = try await client.sync()
        
        XCTAssertGreaterThan(syncResult.entitiesSynced, 0)
        
        // Verify entity exists on server
        let serverEntity = try await testServer.getEntity(id: entity.id)
        XCTAssertEqual(serverEntity?.name, entity.name)
    }
    
    func testConflictResolution() async throws {
        // Create conflicting changes
        let entityId = UUID().uuidString
        
        // Client creates entity
        let clientEntity = Entity(
            id: entityId,
            version: "client-v1",
            entityType: .device,
            name: "Client Name"
        )
        
        // Server has different version
        let serverEntity = Entity(
            id: entityId,
            version: "server-v1",
            entityType: .device,
            name: "Server Name"
        )
        
        testServer.addEntity(serverEntity)
        
        try await client.createEntity(clientEntity)
        let syncResult = try await client.sync()
        
        XCTAssertGreaterThan(syncResult.conflictsResolved, 0)
    }
}
```

#### Offline Operation Tests
```swift
import XCTest
@testable import Wildthing

final class OfflineOperationTests: XCTestCase {
    
    var client: WildthingClient!
    
    override func setUp() {
        super.setUp()
        client = WildthingClient(configuration: Configuration(autoSync: false))
    }
    
    func testOfflineQueue() async throws {
        // Create entities while offline
        for i in 1...10 {
            let entity = Entity(
                id: "entity-\(i)",
                version: "v1",
                entityType: .device,
                name: "Device \(i)"
            )
            try await client.createEntity(entity)
        }
        
        XCTAssertEqual(client.pendingChangesCount, 10)
        
        // Connect and sync
        try await client.connect(
            serverURL: URL(string: "http://localhost:8080")!,
            authToken: "test-token"
        )
        
        let syncResult = try await client.sync()
        
        XCTAssertEqual(syncResult.entitiesSynced, 10)
        XCTAssertEqual(client.pendingChangesCount, 0)
    }
}
```

### 3. UI Tests

#### Bertha App UI Tests
```swift
import XCTest

final class BerthaUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testConnectionFlow() {
        // Navigate to connection screen
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Connection Settings"].tap()
        
        // Enter server details
        let serverURLField = app.textFields["Server URL"]
        serverURLField.tap()
        serverURLField.typeText("http://localhost:8080")
        
        let clientIdField = app.textFields["Client ID"]
        clientIdField.tap()
        clientIdField.typeText("test-client")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("test-password")
        
        // Connect
        app.buttons["Connect"].tap()
        
        // Verify connection status
        XCTAssertTrue(app.staticTexts["Connected"].waitForExistence(timeout: 5))
    }
    
    func testEntityCreation() {
        // Navigate to entities tab
        app.tabBars.buttons["Entities"].tap()
        
        // Create new entity
        app.navigationBars.buttons["Add"].tap()
        
        // Fill entity details
        app.textFields["Entity Name"].tap()
        app.textFields["Entity Name"].typeText("Living Room")
        
        app.buttons["Room"].tap() // Select entity type
        
        app.buttons["Create"].tap()
        
        // Verify entity appears in list
        XCTAssertTrue(app.cells.staticTexts["Living Room"].exists)
    }
    
    func testSyncStatus() {
        // Trigger sync
        app.tabBars.buttons["Sync"].tap()
        app.buttons["Sync Now"].tap()
        
        // Verify sync indicator
        XCTAssertTrue(app.staticTexts["Syncing..."].waitForExistence(timeout: 2))
        
        // Wait for sync completion
        XCTAssertTrue(app.staticTexts["Last synced"].waitForExistence(timeout: 10))
    }
}
```

### 4. Performance Tests

#### Sync Performance Tests
```swift
import XCTest
@testable import Wildthing

final class SyncPerformanceTests: XCTestCase {
    
    var client: WildthingClient!
    
    override func setUp() async throws {
        try await super.setUp()
        client = WildthingClient()
        try await client.connect(
            serverURL: URL(string: "http://localhost:8080")!,
            authToken: "test-token"
        )
    }
    
    func testLargeSyncPerformance() {
        measure {
            let expectation = expectation(description: "Sync completed")
            
            Task {
                // Create 1000 entities
                for i in 1...1000 {
                    let entity = Entity(
                        id: "perf-\(i)",
                        version: "v1",
                        entityType: .device,
                        name: "Device \(i)"
                    )
                    try await client.createEntity(entity)
                }
                
                // Measure sync time
                let start = Date()
                _ = try await client.sync()
                let duration = Date().timeIntervalSince(start)
                
                XCTAssertLessThan(duration, 10.0) // Should complete within 10 seconds
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15)
        }
    }
    
    func testMemoryUsage() {
        // Monitor memory during large operations
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        
        measure(metrics: [XCTMemoryMetric()], options: options) {
            startMeasuring()
            
            Task {
                // Load 5000 entities
                for _ in 1...5000 {
                    _ = Entity(
                        id: UUID().uuidString,
                        version: "v1",
                        entityType: .device,
                        name: "Test Device"
                    )
                }
                
                stopMeasuring()
            }
        }
    }
}
```

## Test Data Management

### Mock Data Factory
```swift
struct TestDataFactory {
    
    static func makeEntity(
        id: String = UUID().uuidString,
        type: EntityType = .device,
        name: String = "Test Entity"
    ) -> Entity {
        return Entity(
            id: id,
            version: UUID().uuidString,
            entityType: type,
            name: name,
            content: [:],
            sourceType: .manual,
            userId: "test-user",
            parentVersions: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static func makeRelationship(
        from: String,
        to: String,
        type: RelationshipType = .controls
    ) -> EntityRelationship {
        return EntityRelationship(
            id: UUID().uuidString,
            fromEntityId: from,
            fromEntityVersion: "v1",
            toEntityId: to,
            toEntityVersion: "v1",
            relationshipType: type,
            properties: [:],
            userId: "test-user",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static func makeHomeGraph() -> (entities: [Entity], relationships: [EntityRelationship]) {
        let home = makeEntity(id: "home-1", type: .home, name: "My Home")
        let livingRoom = makeEntity(id: "room-1", type: .room, name: "Living Room")
        let bedroom = makeEntity(id: "room-2", type: .room, name: "Bedroom")
        let light1 = makeEntity(id: "device-1", type: .device, name: "Living Room Light")
        let light2 = makeEntity(id: "device-2", type: .device, name: "Bedroom Light")
        
        let relationships = [
            makeRelationship(from: "room-1", to: "home-1", type: .locatedIn),
            makeRelationship(from: "room-2", to: "home-1", type: .locatedIn),
            makeRelationship(from: "device-1", to: "room-1", type: .locatedIn),
            makeRelationship(from: "device-2", to: "room-2", type: .locatedIn)
        ]
        
        return ([home, livingRoom, bedroom, light1, light2], relationships)
    }
}
```

## CI/CD Integration

### GitHub Actions Workflow
```yaml
name: Swift Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app
    
    - name: Run Inbetweenies Tests
      run: |
        cd inbetweenies
        swift test --parallel
    
    - name: Run Wildthing Tests
      run: |
        cd wildthing
        swift test --parallel
    
    - name: Run Bertha Tests
      run: |
        cd bertha
        xcodebuild test \
          -scheme Bertha \
          -destination 'platform=iOS Simulator,name=iPhone 15'
    
    - name: Generate Coverage Report
      run: |
        xcrun llvm-cov export \
          -format="lcov" \
          -instr-profile=.build/debug/codecov/default.profdata \
          .build/debug/*.xctest/Contents/MacOS/* > coverage.lcov
    
    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.lcov
        fail_ci_if_error: true
```

## Test Execution Guidelines

### Local Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter EntityTests

# Run with coverage
swift test --enable-code-coverage

# Run UI tests
xcodebuild test -scheme Bertha -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Organization
- One test file per source file
- Group related tests in test suites
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Mock external dependencies
- Use test fixtures for complex data

### Best Practices
1. **Isolation**: Each test should be independent
2. **Speed**: Keep unit tests under 100ms
3. **Reliability**: No flaky tests
4. **Coverage**: Aim for high coverage but focus on quality
5. **Documentation**: Comment complex test scenarios
6. **Maintenance**: Refactor tests with production code

## Success Metrics
1. All tests passing on CI/CD
2. Code coverage targets met
3. No flaky tests
4. Performance benchmarks satisfied
5. Memory leak tests passing
6. UI tests covering critical flows
7. Integration tests with real server passing
8. Test execution time under 5 minutes