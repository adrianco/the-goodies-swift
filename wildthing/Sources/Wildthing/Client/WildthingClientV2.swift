/**
 * File: WildthingClientV2.swift
 * Purpose: Main client implementation for FunkyGibbon server synchronization
 * 
 * CONTEXT:
 * This is the primary interface for client applications to interact with the
 * distributed knowledge graph. It manages connections, authentication, data
 * synchronization, and local/remote state coordination.
 * 
 * FUNCTIONALITY:
 * - Connection management with authentication support
 * - Bidirectional synchronization using vector clocks
 * - Automatic sync with configurable intervals
 * - Offline support with pending changes tracking
 * - Network monitoring and auto-reconnection
 * - Entity and relationship CRUD operations
 * 
 * PYTHON PARITY:
 * Corresponds to blowing-off/client.py in Python implementation
 * - ✅ Connection management (connect/disconnect)
 * - ✅ Authentication (token and password-based)
 * - ✅ Sync operations (delta and full sync)
 * - ✅ Entity/relationship operations
 * - ✅ Offline queue management
 * - ✅ Auto-sync capability
 * - ⚠️  MCP tools integration (not yet implemented)
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial full implementation
 */

import Foundation
import Combine
import Inbetweenies

/// Main client for synchronizing with FunkyGibbon server (Full Implementation)
@available(iOS 15.0, macOS 12.0, *)
public class WildthingClientV2: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var pendingChangesCount: Int = 0
    @Published public private(set) var isNetworkAvailable: Bool = false
    
    // MARK: - Private Properties
    
    private var configuration: Configuration
    private let authManager: AuthManager
    private let syncEngine: SyncEngine
    private let localStorage: LocalStorage
    private let networkMonitor: NetworkMonitor
    
    private let deviceId: String
    private var userId: String?
    private var syncTimer: Timer?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = .default) throws {
        self.configuration = configuration
        self.deviceId = Self.getOrCreateDeviceId()
        
        // Initialize components
        self.authManager = AuthManager(configuration: configuration)
        self.localStorage = try LocalStorage(configuration: configuration)
        self.networkMonitor = NetworkMonitor()
        
        self.syncEngine = SyncEngine(
            deviceId: deviceId,
            localStorage: localStorage,
            authManager: authManager,
            configuration: configuration
        )
        
        setupBindings()
        setupAutoSync()
    }
    
    // MARK: - Connection Management
    
    /// Connect to the server
    public func connect(
        serverURL: URL,
        authToken: String? = nil,
        clientId: String? = nil,
        password: String? = nil
    ) async throws {
        // Update configuration
        configuration.serverURL = serverURL
        
        // Check network availability
        guard await NetworkReachability.canReachServer(at: serverURL) else {
            throw WildthingError.networkError("Cannot reach server")
        }
        
        // Authenticate
        if let authToken = authToken {
            try await authManager.setToken(authToken)
            self.userId = clientId ?? "user-\(deviceId)"
        } else if let clientId = clientId, let password = password {
            let token = try await authManager.authenticate(
                clientId: clientId,
                password: password,
                serverURL: serverURL
            )
            self.userId = clientId
        } else {
            throw WildthingError.authenticationRequired
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
        
        stopAutoSync()
        await authManager.clearToken()
        userId = nil
    }
    
    // MARK: - Synchronization
    
    /// Perform synchronization
    public func sync() async throws -> SyncResult {
        guard isConnected else {
            throw WildthingError.notConnected
        }
        
        guard let userId = userId else {
            throw WildthingError.authenticationRequired
        }
        
        // Check network before syncing
        if !networkMonitor.isConnected {
            throw WildthingError.networkError("No network connection")
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncStatus = .syncing
        }
        
        do {
            let result = try await syncEngine.sync(userId: userId)
            
            await MainActor.run {
                self.lastSyncDate = Date()
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
        
        guard let userId = userId else {
            throw WildthingError.authenticationRequired
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncStatus = .syncing
        }
        
        do {
            let result = try await syncEngine.fullSync(userId: userId)
            
            await MainActor.run {
                self.lastSyncDate = Date()
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
    
    // MARK: - Entity Operations
    
    /// Create a new entity
    public func createEntity(_ entity: Entity) async throws {
        try await localStorage.createEntity(entity)
        
        if configuration.autoSync && isConnected && networkMonitor.isConnected {
            try? await sync()
        }
    }
    
    /// Update an existing entity
    public func updateEntity(_ entity: Entity) async throws {
        try await localStorage.updateEntity(entity)
        
        if configuration.autoSync && isConnected && networkMonitor.isConnected {
            try? await sync()
        }
    }
    
    /// Delete an entity
    public func deleteEntity(id: String) async throws {
        try await localStorage.deleteEntity(id: id)
        
        if configuration.autoSync && isConnected && networkMonitor.isConnected {
            try? await sync()
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
        
        if configuration.autoSync && isConnected && networkMonitor.isConnected {
            try? await sync()
        }
    }
    
    /// Delete a relationship
    public func deleteRelationship(id: String) async throws {
        try await localStorage.deleteRelationship(id: id)
        
        if configuration.autoSync && isConnected && networkMonitor.isConnected {
            try? await sync()
        }
    }
    
    /// Get relationships for an entity
    public func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        return try await localStorage.getRelationships(for: entityId)
    }
    
    // MARK: - Offline Support
    
    /// Get pending changes count
    public func getPendingChangesCount() async throws -> Int {
        let changes = try await localStorage.getPendingChanges()
        return changes.count
    }
    
    /// Clear all local data
    public func clearLocalData() async throws {
        try await localStorage.clearAll()
        
        await MainActor.run {
            self.pendingChangesCount = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitor network connectivity
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isNetworkAvailable in
                self?.isNetworkAvailable = isNetworkAvailable
                
                // Auto-sync when network becomes available
                if isNetworkAvailable,
                   let self = self,
                   self.configuration.autoSync,
                   self.isConnected,
                   !self.isSyncing {
                    Task {
                        try? await self.sync()
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
    
    private func setupAutoSync() {
        guard configuration.autoSync else { return }
        
        stopAutoSync()
        
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.syncInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self,
                  self.isConnected,
                  !self.isSyncing,
                  self.networkMonitor.isConnected else {
                return
            }
            
            Task {
                try? await self.sync()
            }
        }
    }
    
    private func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
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
    
    deinit {
        stopAutoSync()
        networkMonitor.stopMonitoring()
    }
}