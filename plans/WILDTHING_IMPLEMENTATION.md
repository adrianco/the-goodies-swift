# Wildthing Package Implementation Plan

## Overview
Detailed implementation plan for the Wildthing Swift package - the client layer implementing synchronization with FunkyGibbon server and local storage capabilities.

## Package Structure
```
wildthing/
├── Package.swift
├── Sources/
│   └── Wildthing/
│       ├── Client/
│       │   ├── WildthingClient.swift
│       │   ├── ConnectionManager.swift
│       │   └── Configuration.swift
│       ├── Auth/
│       │   ├── AuthManager.swift
│       │   ├── TokenStorage.swift
│       │   └── JWTHandler.swift
│       ├── Sync/
│       │   ├── SyncEngine.swift
│       │   ├── SyncQueue.swift
│       │   ├── ConflictHandler.swift
│       │   └── SyncMonitor.swift
│       ├── Storage/
│       │   ├── LocalStorage.swift
│       │   ├── CoreDataStack.swift
│       │   ├── EntityStore.swift
│       │   ├── RelationshipStore.swift
│       │   └── Migration.swift
│       ├── Graph/
│       │   ├── LocalGraphStorage.swift
│       │   ├── LocalGraphOperations.swift
│       │   └── GraphCache.swift
│       ├── Network/
│       │   ├── APIClient.swift
│       │   ├── RequestBuilder.swift
│       │   ├── ResponseHandler.swift
│       │   └── NetworkMonitor.swift
│       ├── MCP/
│       │   ├── LocalMCPClient.swift
│       │   └── ToolExecutor.swift
│       ├── Models/
│       │   ├── ClientModels.swift
│       │   └── CoreDataModels.xcdatamodeld
│       └── Wildthing.swift
└── Tests/
    └── WildthingTests/
        ├── ClientTests/
        ├── AuthTests/
        ├── SyncTests/
        ├── StorageTests/
        └── IntegrationTests/
```

## Implementation Details

### 1. Client Module

#### WildthingClient.swift
```swift
import Foundation
import Combine
import Inbetweenies

/// Main client for synchronizing with FunkyGibbon server
public class WildthingClient: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingChangesCount: Int = 0
    
    // MARK: - Private Properties
    private let configuration: Configuration
    private let authManager: AuthManager
    private let syncEngine: SyncEngine
    private let localStorage: LocalStorage
    private let apiClient: APIClient
    private let networkMonitor: NetworkMonitor
    private let graphOperations: LocalGraphOperations
    private let mcpClient: LocalMCPClient
    
    private var cancellables = Set<AnyCancellable>()
    private let deviceId: String
    
    // MARK: - Initialization
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.deviceId = Self.getOrCreateDeviceId()
        
        // Initialize components
        self.authManager = AuthManager(configuration: configuration)
        self.localStorage = LocalStorage(configuration: configuration)
        self.apiClient = APIClient(configuration: configuration)
        self.networkMonitor = NetworkMonitor()
        
        let graphStorage = LocalGraphStorage(storage: localStorage)
        self.graphOperations = LocalGraphOperations(storage: graphStorage)
        self.mcpClient = LocalMCPClient(graphStorage: graphStorage)
        
        self.syncEngine = SyncEngine(
            deviceId: deviceId,
            localStorage: localStorage,
            apiClient: apiClient,
            authManager: authManager
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Connect to the server
    public func connect(
        serverURL: URL,
        authToken: String? = nil,
        clientId: String? = nil,
        password: String? = nil
    ) async throws {
        // Update configuration with server URL
        configuration.serverURL = serverURL
        
        // Authenticate if needed
        if let authToken = authToken {
            try await authManager.setToken(authToken)
        } else if let clientId = clientId, let password = password {
            let token = try await authManager.authenticate(
                clientId: clientId,
                password: password,
                serverURL: serverURL
            )
            try await authManager.setToken(token)
        } else {
            throw WildthingError.authenticationRequired
        }
        
        // Initialize local storage
        try await localStorage.initialize()
        
        // Test connection
        try await apiClient.testConnection()
        
        await MainActor.run {
            self.isConnected = true
        }
        
        // Perform initial sync
        try await sync()
    }
    
    /// Disconnect from server
    public func disconnect() async {
        await MainActor.run {
            self.isConnected = false
        }
        
        // Clear auth token
        await authManager.clearToken()
        
        // Stop any ongoing sync
        await syncEngine.stop()
    }
    
    /// Perform synchronization
    public func sync() async throws -> SyncResult {
        guard isConnected else {
            throw WildthingError.notConnected
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncStatus = .syncing
        }
        
        do {
            let result = try await syncEngine.sync()
            
            await MainActor.run {
                self.lastSyncDate = Date()
                self.pendingChangesCount = 0
                self.syncStatus = .success
                self.isSyncing = false
            }
            
            return result
        } catch {
            await MainActor.run {
                self.syncStatus = .failed(error)
                self.isSyncing = false
            }
            throw error
        }
    }
    
    /// Perform full synchronization
    public func fullSync() async throws -> SyncResult {
        guard isConnected else {
            throw WildthingError.notConnected
        }
        
        return try await syncEngine.fullSync()
    }
    
    // MARK: - Entity Operations
    
    /// Create a new entity
    public func createEntity(_ entity: Entity) async throws {
        try await localStorage.createEntity(entity)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Update an existing entity
    public func updateEntity(_ entity: Entity) async throws {
        try await localStorage.updateEntity(entity)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Delete an entity
    public func deleteEntity(id: String) async throws {
        try await localStorage.deleteEntity(id: id)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Get entity by ID
    public func getEntity(id: String) async throws -> Entity? {
        return try await localStorage.getEntity(id: id)
    }
    
    /// List entities
    public func listEntities(type: EntityType? = nil) async throws -> [Entity] {
        return try await localStorage.listEntities(type: type)
    }
    
    // MARK: - Relationship Operations
    
    /// Create a relationship
    public func createRelationship(_ relationship: EntityRelationship) async throws {
        try await localStorage.createRelationship(relationship)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Delete a relationship
    public func deleteRelationship(id: String) async throws {
        try await localStorage.deleteRelationship(id: id)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Get relationships for an entity
    public func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        return try await localStorage.getRelationships(for: entityId)
    }
    
    // MARK: - MCP Tool Execution
    
    /// Execute an MCP tool
    public func executeTool(_ tool: MCPTool, parameters: [String: Any]) async throws -> MCPToolResult {
        return try await mcpClient.executeTool(tool, parameters: parameters)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor network connectivity
        networkMonitor.$isConnected
            .sink { [weak self] isNetworkAvailable in
                if isNetworkAvailable && self?.configuration.autoSync == true {
                    Task {
                        try? await self?.sync()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor pending changes
        localStorage.pendingChangesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.pendingChangesCount = count
            }
            .store(in: &cancellables)
    }
    
    private static func getOrCreateDeviceId() -> String {
        let key = "wildthing.deviceId"
        if let deviceId = UserDefaults.standard.string(forKey: key) {
            return deviceId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
    }
}

// MARK: - Supporting Types

public enum SyncStatus: Equatable {
    case idle
    case syncing
    case success
    case failed(Error)
    
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.success, .success):
            return true
        case (.failed(let e1), .failed(let e2)):
            return (e1 as NSError) == (e2 as NSError)
        default:
            return false
        }
    }
}

public enum WildthingError: LocalizedError {
    case notConnected
    case authenticationRequired
    case authenticationFailed(String)
    case syncFailed(String)
    case storageError(String)
    case networkError(String)
    case invalidData(String)
    case serverError(Int, String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .authenticationRequired:
            return "Authentication required"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        }
    }
}
```

#### Configuration.swift
```swift
import Foundation

/// Client configuration
public struct Configuration {
    public var serverURL: URL?
    public var autoSync: Bool
    public var syncInterval: TimeInterval
    public var maxRetries: Int
    public var retryDelay: TimeInterval
    public var databasePath: String
    public var useCloudKit: Bool
    public var debugMode: Bool
    
    public init(
        serverURL: URL? = nil,
        autoSync: Bool = true,
        syncInterval: TimeInterval = 300, // 5 minutes
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0,
        databasePath: String = "wildthing.sqlite",
        useCloudKit: Bool = false,
        debugMode: Bool = false
    ) {
        self.serverURL = serverURL
        self.autoSync = autoSync
        self.syncInterval = syncInterval
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.databasePath = databasePath
        self.useCloudKit = useCloudKit
        self.debugMode = debugMode
    }
    
    public static let `default` = Configuration()
}
```

### 2. Auth Module

#### AuthManager.swift
```swift
import Foundation
import Security

/// Manages authentication and token storage
public class AuthManager {
    private let configuration: Configuration
    private let tokenStorage: TokenStorage
    private var currentToken: String?
    
    init(configuration: Configuration) {
        self.configuration = configuration
        self.tokenStorage = TokenStorage()
    }
    
    /// Authenticate with server
    public func authenticate(
        clientId: String,
        password: String,
        serverURL: URL
    ) async throws -> String {
        let request = AuthRequest(
            clientId: clientId,
            password: password
        )
        
        var urlRequest = URLRequest(url: serverURL.appendingPathComponent("/api/auth"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WildthingError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WildthingError.authenticationFailed("Status: \(httpResponse.statusCode)")
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        return authResponse.token
    }
    
    /// Set authentication token
    public func setToken(_ token: String) async throws {
        currentToken = token
        try tokenStorage.saveToken(token)
    }
    
    /// Get current token
    public func getToken() -> String? {
        if let token = currentToken {
            return token
        }
        currentToken = tokenStorage.loadToken()
        return currentToken
    }
    
    /// Clear token
    public func clearToken() async {
        currentToken = nil
        tokenStorage.deleteToken()
    }
    
    /// Refresh token if needed
    public func refreshTokenIfNeeded() async throws {
        // Check token expiration and refresh if needed
        // Implementation depends on JWT structure
    }
}

// MARK: - Auth Models

struct AuthRequest: Codable {
    let clientId: String
    let password: String
}

struct AuthResponse: Codable {
    let token: String
    let expiresIn: Int?
}
```

### 3. Sync Module

#### SyncEngine.swift
```swift
import Foundation
import Inbetweenies

/// Handles synchronization with server
class SyncEngine {
    private let deviceId: String
    private let localStorage: LocalStorage
    private let apiClient: APIClient
    private let authManager: AuthManager
    private let conflictHandler: ConflictHandler
    private let syncQueue: SyncQueue
    
    private var vectorClock: VectorClock
    private var isSyncing = false
    
    init(
        deviceId: String,
        localStorage: LocalStorage,
        apiClient: APIClient,
        authManager: AuthManager
    ) {
        self.deviceId = deviceId
        self.localStorage = localStorage
        self.apiClient = apiClient
        self.authManager = authManager
        self.conflictHandler = ConflictHandler()
        self.syncQueue = SyncQueue()
        self.vectorClock = VectorClock()
    }
    
    /// Perform sync with server
    func sync() async throws -> SyncResult {
        guard !isSyncing else {
            throw WildthingError.syncFailed("Sync already in progress")
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // Get pending changes
        let pendingChanges = try await localStorage.getPendingChanges()
        
        // Build sync request
        let syncRequest = SyncRequest(
            deviceId: deviceId,
            userId: getUserId(),
            syncType: pendingChanges.isEmpty ? .delta : .delta,
            vectorClock: vectorClock,
            changes: pendingChanges
        )
        
        // Send sync request
        let syncResponse = try await apiClient.sync(request: syncRequest)
        
        // Handle conflicts
        var conflicts: [ConflictInfo] = []
        if !syncResponse.conflicts.isEmpty {
            conflicts = try await handleConflicts(syncResponse.conflicts)
        }
        
        // Apply remote changes
        try await applyRemoteChanges(syncResponse.changes)
        
        // Update vector clock
        vectorClock.merge(with: syncResponse.vectorClock)
        
        // Clear pending changes
        try await localStorage.clearPendingChanges()
        
        return SyncResult(
            entitiesSynced: syncResponse.syncStats.entitiesSynced,
            relationshipsSynced: syncResponse.syncStats.relationshipsSynced,
            conflictsResolved: conflicts.count,
            duration: syncResponse.syncStats.durationMs
        )
    }
    
    /// Perform full sync
    func fullSync() async throws -> SyncResult {
        isSyncing = true
        defer { isSyncing = false }
        
        // Clear local data
        try await localStorage.clearAll()
        
        // Request full sync
        let syncRequest = SyncRequest(
            deviceId: deviceId,
            userId: getUserId(),
            syncType: .full,
            vectorClock: VectorClock(),
            changes: []
        )
        
        let syncResponse = try await apiClient.sync(request: syncRequest)
        
        // Apply all remote changes
        try await applyRemoteChanges(syncResponse.changes)
        
        // Update vector clock
        vectorClock = syncResponse.vectorClock
        
        return SyncResult(
            entitiesSynced: syncResponse.syncStats.entitiesSynced,
            relationshipsSynced: syncResponse.syncStats.relationshipsSynced,
            conflictsResolved: 0,
            duration: syncResponse.syncStats.durationMs
        )
    }
    
    /// Stop any ongoing sync
    func stop() async {
        isSyncing = false
    }
    
    // MARK: - Private Methods
    
    private func handleConflicts(_ conflicts: [ConflictInfo]) async throws -> [ConflictInfo] {
        var resolved: [ConflictInfo] = []
        
        for conflict in conflicts {
            if let localEntity = try await localStorage.getEntity(id: conflict.entityId),
               let remoteEntity = try await fetchRemoteEntity(id: conflict.entityId) {
                
                let resolvedEntity = conflictHandler.resolve(
                    local: localEntity,
                    remote: remoteEntity,
                    strategy: conflict.resolutionStrategy
                )
                
                try await localStorage.updateEntity(resolvedEntity)
                resolved.append(conflict)
            }
        }
        
        return resolved
    }
    
    private func applyRemoteChanges(_ changes: [SyncChange]) async throws {
        for change in changes {
            switch change.changeType {
            case .create:
                if let entity = change.entity {
                    try await localStorage.createEntity(entity.toEntity())
                }
                for relationship in change.relationships {
                    try await localStorage.createRelationship(relationship.toRelationship())
                }
                
            case .update:
                if let entity = change.entity {
                    try await localStorage.updateEntity(entity.toEntity())
                }
                
            case .delete:
                if let entity = change.entity {
                    try await localStorage.deleteEntity(id: entity.id)
                }
            }
        }
    }
    
    private func fetchRemoteEntity(id: String) async throws -> Entity? {
        // Fetch specific entity from server
        return try await apiClient.getEntity(id: id)
    }
    
    private func getUserId() -> String {
        // Get user ID from auth manager or configuration
        return "user-\(deviceId)"
    }
}
```

### 4. Storage Module

#### LocalStorage.swift
```swift
import Foundation
import CoreData
import Inbetweenies
import Combine

/// Manages local persistent storage
class LocalStorage {
    private let configuration: Configuration
    private let coreDataStack: CoreDataStack
    private let entityStore: EntityStore
    private let relationshipStore: RelationshipStore
    
    private let pendingChangesSubject = CurrentValueSubject<Int, Never>(0)
    var pendingChangesPublisher: AnyPublisher<Int, Never> {
        pendingChangesSubject.eraseToAnyPublisher()
    }
    
    init(configuration: Configuration) {
        self.configuration = configuration
        self.coreDataStack = CoreDataStack(modelName: "Wildthing")
        self.entityStore = EntityStore(context: coreDataStack.viewContext)
        self.relationshipStore = RelationshipStore(context: coreDataStack.viewContext)
    }
    
    /// Initialize storage
    func initialize() async throws {
        try await coreDataStack.loadStores()
    }
    
    // MARK: - Entity Operations
    
    func createEntity(_ entity: Entity) async throws {
        try await entityStore.create(entity)
        updatePendingChangesCount()
    }
    
    func updateEntity(_ entity: Entity) async throws {
        try await entityStore.update(entity)
        updatePendingChangesCount()
    }
    
    func deleteEntity(id: String) async throws {
        try await entityStore.delete(id: id)
        updatePendingChangesCount()
    }
    
    func getEntity(id: String) async throws -> Entity? {
        return try await entityStore.fetch(id: id)
    }
    
    func listEntities(type: EntityType? = nil) async throws -> [Entity] {
        return try await entityStore.fetchAll(type: type)
    }
    
    // MARK: - Relationship Operations
    
    func createRelationship(_ relationship: EntityRelationship) async throws {
        try await relationshipStore.create(relationship)
        updatePendingChangesCount()
    }
    
    func deleteRelationship(id: String) async throws {
        try await relationshipStore.delete(id: id)
        updatePendingChangesCount()
    }
    
    func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        return try await relationshipStore.fetchForEntity(entityId)
    }
    
    // MARK: - Sync Operations
    
    func getPendingChanges() async throws -> [SyncChange] {
        // Fetch entities and relationships marked as pending sync
        let pendingEntities = try await entityStore.fetchPending()
        let pendingRelationships = try await relationshipStore.fetchPending()
        
        var changes: [SyncChange] = []
        
        for entity in pendingEntities {
            changes.append(SyncChange(
                changeType: .update,
                entity: entity.toEntityChange(),
                relationships: []
            ))
        }
        
        for relationship in pendingRelationships {
            changes.append(SyncChange(
                changeType: .update,
                entity: nil,
                relationships: [relationship.toRelationshipChange()]
            ))
        }
        
        return changes
    }
    
    func clearPendingChanges() async throws {
        try await entityStore.clearPendingFlags()
        try await relationshipStore.clearPendingFlags()
        pendingChangesSubject.send(0)
    }
    
    func clearAll() async throws {
        try await entityStore.deleteAll()
        try await relationshipStore.deleteAll()
        pendingChangesSubject.send(0)
    }
    
    // MARK: - Private Methods
    
    private func updatePendingChangesCount() {
        Task {
            let count = try await entityStore.countPending() + 
                       try await relationshipStore.countPending()
            pendingChangesSubject.send(count)
        }
    }
}
```

### 5. Network Module

#### APIClient.swift
```swift
import Foundation
import Inbetweenies

/// Handles API communication with server
class APIClient {
    private let configuration: Configuration
    private let session: URLSession
    private let requestBuilder: RequestBuilder
    private let responseHandler: ResponseHandler
    
    init(configuration: Configuration) {
        self.configuration = configuration
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: config)
        self.requestBuilder = RequestBuilder(configuration: configuration)
        self.responseHandler = ResponseHandler()
    }
    
    /// Test connection to server
    func testConnection() async throws {
        guard let serverURL = configuration.serverURL else {
            throw WildthingError.networkError("Server URL not configured")
        }
        
        let url = serverURL.appendingPathComponent("/api/health")
        let request = try requestBuilder.buildRequest(for: url, method: "GET")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WildthingError.networkError("Connection test failed")
        }
    }
    
    /// Send sync request
    func sync(request syncRequest: SyncRequest) async throws -> SyncResponse {
        guard let serverURL = configuration.serverURL else {
            throw WildthingError.networkError("Server URL not configured")
        }
        
        let url = serverURL.appendingPathComponent("/api/sync")
        var request = try requestBuilder.buildRequest(for: url, method: "POST")
        request.httpBody = try JSONEncoder().encode(syncRequest)
        
        let (data, response) = try await session.data(for: request)
        
        try responseHandler.validate(response)
        
        return try JSONDecoder().decode(SyncResponse.self, from: data)
    }
    
    /// Get specific entity
    func getEntity(id: String) async throws -> Entity? {
        guard let serverURL = configuration.serverURL else {
            throw WildthingError.networkError("Server URL not configured")
        }
        
        let url = serverURL.appendingPathComponent("/api/entities/\(id)")
        let request = try requestBuilder.buildRequest(for: url, method: "GET")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WildthingError.networkError("Invalid response")
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        try responseHandler.validate(response)
        
        return try JSONDecoder().decode(Entity.self, from: data)
    }
}
```

## Testing Plan

### Unit Tests

#### Client Tests
- Client initialization
- Connection management
- Configuration handling
- Device ID persistence

#### Auth Tests
- Token storage in keychain
- Authentication flow
- Token refresh logic
- Token expiration handling

#### Sync Tests
- Sync request building
- Conflict resolution
- Vector clock management
- Pending changes tracking

#### Storage Tests
- Core Data operations
- Entity CRUD
- Relationship management
- Migration scenarios

### Integration Tests
- Full sync flow with mock server
- Offline operation and queue
- Network failure recovery
- Concurrent operations
- Memory management

## Package.swift Configuration
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Wildthing",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "Wildthing",
            targets: ["Wildthing"]),
    ],
    dependencies: [
        .package(path: "../inbetweenies")
    ],
    targets: [
        .target(
            name: "Wildthing",
            dependencies: [
                .product(name: "Inbetweenies", package: "inbetweenies")
            ],
            resources: [
                .process("Models/CoreDataModels.xcdatamodeld")
            ]),
        .testTarget(
            name: "WildthingTests",
            dependencies: ["Wildthing"]),
    ]
)
```

## Success Metrics
1. Successful connection to FunkyGibbon server
2. Full and delta sync working correctly
3. Offline operation with queue management
4. Conflict resolution handling all scenarios
5. Token management with secure storage
6. Core Data persistence working correctly
7. All MCP tools executable locally
8. Memory usage under 50MB for 1000 entities
9. 80%+ test coverage