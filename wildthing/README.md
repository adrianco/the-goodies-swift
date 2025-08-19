# Wildthing

Swift client package for The Goodies distributed MCP knowledge graph system.

## Features

- 🔐 **Secure Authentication**: JWT token management with Keychain storage
- 💾 **Local Persistence**: SQLite database for offline operation
- 🔄 **Bidirectional Sync**: Full and delta synchronization with conflict resolution
- 📡 **Network Monitoring**: Automatic reconnection and sync when network available
- 🎯 **Type Safety**: Strongly typed Swift models
- ⚡ **Performance**: Optimized database queries with indexes
- 🧪 **Well Tested**: Comprehensive unit and integration tests

## Installation

### Swift Package Manager

Add Wildthing to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../wildthing")
]
```

## Usage

### Basic Setup

```swift
import Wildthing
import Inbetweenies

// Create client with default configuration
let client = try WildthingClientV2()

// Or with custom configuration
let config = Configuration(
    autoSync: true,
    syncInterval: 300, // 5 minutes
    databasePath: "myapp.sqlite"
)
let client = try WildthingClientV2(configuration: config)
```

### Authentication

```swift
// Connect with username/password
try await client.connect(
    serverURL: URL(string: "https://funkygibbon.example.com")!,
    clientId: "user@example.com",
    password: "securePassword"
)

// Or with existing token
try await client.connect(
    serverURL: URL(string: "https://funkygibbon.example.com")!,
    authToken: "jwt-token-here"
)
```

### Working with Entities

```swift
// Create entity
let device = Entity(
    entityType: .device,
    name: "Living Room Light",
    content: [
        "type": AnyCodable("smart_bulb"),
        "brand": AnyCodable("Philips Hue"),
        "brightness": AnyCodable(100)
    ]
)
try await client.createEntity(device)

// Get entity
if let entity = try await client.getEntity(id: "device-123") {
    print("Found: \(entity.name)")
}

// List entities
let allDevices = try await client.listEntities(type: .device)
print("Found \(allDevices.count) devices")

// Update entity
var updatedDevice = device
updatedDevice.content["brightness"] = AnyCodable(50)
try await client.updateEntity(updatedDevice)

// Delete entity
try await client.deleteEntity(id: device.id)
```

### Working with Relationships

```swift
// Create relationship
let relationship = EntityRelationship(
    fromEntityId: roomId,
    fromEntityVersion: roomVersion,
    toEntityId: deviceId,
    toEntityVersion: deviceVersion,
    relationshipType: .contains
)
try await client.createRelationship(relationship)

// Get relationships
let relationships = try await client.getRelationships(for: roomId)
for rel in relationships {
    print("\(rel.relationshipType): \(rel.toEntityId)")
}
```

### Synchronization

```swift
// Manual sync
let result = try await client.sync()
print("Synced \(result.entitiesSynced) entities")

// Full sync (clears local and fetches all)
let fullResult = try await client.fullSync()

// Check pending changes
print("Pending changes: \(client.pendingChangesCount)")

// Auto-sync is enabled by default
// Syncs automatically on network availability and at intervals
```

### Offline Support

```swift
// Works offline automatically
// Changes are queued and synced when network available

// Monitor sync status
client.$syncStatus
    .sink { status in
        switch status {
        case .idle:
            print("Ready")
        case .syncing:
            print("Syncing...")
        case .success:
            print("Sync completed")
        case .failed(let error):
            print("Sync failed: \(error)")
        }
    }
    .store(in: &cancellables)

// Monitor network
client.$isNetworkAvailable
    .sink { isAvailable in
        print("Network: \(isAvailable ? "Available" : "Offline")")
    }
    .store(in: &cancellables)
```

## Architecture

### Core Components

- **WildthingClientV2**: Main client interface with async/await API
- **LocalStorage**: SQLite persistence layer with change tracking
- **SyncEngine**: Handles synchronization logic and conflict resolution
- **AuthManager**: Secure token management with Keychain
- **NetworkMonitor**: Monitors connectivity and triggers auto-sync

### Database Schema

- **Entities**: Stores all entity data with version tracking
- **Relationships**: Stores graph edges between entities
- **SyncMetadata**: Tracks sync state and vector clocks
- **OfflineQueue**: Manages pending operations

### Sync Protocol

Implements the Inbetweenies-v2 protocol:
- Vector clocks for distributed state tracking
- Conflict resolution strategies (last-write-wins, merge, manual)
- Delta and full sync modes
- Cursor-based pagination for large datasets

## Testing

Run tests with:

```bash
swift test
```

Test coverage includes:
- LocalStorage operations
- Authentication flows
- Sync engine logic
- Conflict resolution
- Network monitoring
- Offline queue management

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 5.7+
- Xcode 14.0+

## Dependencies

- [Inbetweenies](../inbetweenies): Protocol definitions
- [SQLite.swift](https://github.com/stephencelis/SQLite.swift): Database layer

## License

MIT - See LICENSE file for details