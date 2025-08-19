import Foundation
import Combine
import Inbetweenies

/// Sync status for the client
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

/// Main client for synchronizing with FunkyGibbon server
@available(iOS 15.0, macOS 12.0, *)
public class WildthingClient: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingChangesCount: Int = 0
    
    // MARK: - Private Properties
    private let configuration: Configuration
    private var deviceId: String
    private var userId: String?
    private var authToken: String?
    
    // Simplified storage for MVP
    private var entities: [String: Entity] = [:]
    private var relationships: [String: EntityRelationship] = [:]
    private var vectorClock = VectorClock()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.deviceId = Self.getOrCreateDeviceId()
        
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
        // For MVP, just store the connection info
        configuration.serverURL = serverURL
        
        if let authToken = authToken {
            self.authToken = authToken
            self.userId = clientId ?? "user-\(deviceId)"
        } else if let clientId = clientId, let password = password {
            // Simulate authentication
            self.authToken = "simulated-jwt-token"
            self.userId = clientId
        } else {
            throw WildthingError.authenticationRequired
        }
        
        // Test connection (simplified for MVP)
        guard configuration.serverURL != nil else {
            throw WildthingError.networkError("Invalid server URL")
        }
        
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
        
        authToken = nil
        userId = nil
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
            // For MVP, simulate a sync operation
            let result = SyncResult(
                entitiesSynced: entities.count,
                relationshipsSynced: relationships.count,
                conflictsResolved: 0,
                duration: 100
            )
            
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
        
        // Clear local data
        entities.removeAll()
        relationships.removeAll()
        vectorClock = VectorClock()
        
        return try await sync()
    }
    
    // MARK: - Entity Operations
    
    /// Create a new entity
    public func createEntity(_ entity: Entity) async throws {
        entities[entity.id] = entity
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Update an existing entity
    public func updateEntity(_ entity: Entity) async throws {
        guard entities[entity.id] != nil else {
            throw WildthingError.invalidData("Entity not found")
        }
        
        entities[entity.id] = entity
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Delete an entity
    public func deleteEntity(id: String) async throws {
        guard entities[id] != nil else {
            throw WildthingError.invalidData("Entity not found")
        }
        
        entities.removeValue(forKey: id)
        
        // Remove related relationships
        relationships = relationships.filter { _, relationship in
            relationship.fromEntityId != id && relationship.toEntityId != id
        }
        
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Get entity by ID
    public func getEntity(id: String) async throws -> Entity? {
        return entities[id]
    }
    
    /// List entities
    public func listEntities(type: EntityType? = nil) async throws -> [Entity] {
        if let type = type {
            return entities.values.filter { $0.entityType == type }
        }
        return Array(entities.values)
    }
    
    // MARK: - Relationship Operations
    
    /// Create a relationship
    public func createRelationship(_ relationship: EntityRelationship) async throws {
        relationships[relationship.id] = relationship
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Delete a relationship
    public func deleteRelationship(id: String) async throws {
        guard relationships[id] != nil else {
            throw WildthingError.invalidData("Relationship not found")
        }
        
        relationships.removeValue(forKey: id)
        pendingChangesCount += 1
        
        if configuration.autoSync && isConnected {
            try await sync()
        }
    }
    
    /// Get relationships for an entity
    public func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        return relationships.values.filter { relationship in
            relationship.fromEntityId == entityId || relationship.toEntityId == entityId
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Setup any reactive bindings here
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