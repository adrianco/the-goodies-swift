import Foundation
import Inbetweenies

/// Handles synchronization with the server
public class SyncEngine {
    
    // MARK: - Properties
    
    private let deviceId: String
    private let localStorage: LocalStorage
    private let authManager: AuthManager
    private let configuration: Configuration
    
    private var vectorClock: VectorClock
    private var cursor: String?
    private var isSyncing = false
    private let syncQueue = DispatchQueue(label: "wildthing.sync", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(
        deviceId: String,
        localStorage: LocalStorage,
        authManager: AuthManager,
        configuration: Configuration
    ) {
        self.deviceId = deviceId
        self.localStorage = localStorage
        self.authManager = authManager
        self.configuration = configuration
        self.vectorClock = VectorClock()
        
        // Load sync metadata
        Task {
            await loadSyncMetadata()
        }
    }
    
    // MARK: - Public Methods
    
    /// Perform sync with server
    public func sync(userId: String) async throws -> SyncResult {
        guard !isSyncing else {
            throw WildthingError.syncFailed("Sync already in progress")
        }
        
        guard let serverURL = configuration.serverURL else {
            throw WildthingError.networkError("Server URL not configured")
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let startTime = Date()
        
        // Get pending changes
        let pendingChanges = try await localStorage.getPendingChanges()
        
        // Build sync request
        let syncRequest = SyncRequest(
            deviceId: deviceId,
            userId: userId,
            syncType: pendingChanges.isEmpty ? .delta : .delta,
            vectorClock: vectorClock,
            changes: pendingChanges,
            cursor: cursor
        )
        
        // Send sync request
        let syncResponse = try await sendSyncRequest(syncRequest, to: serverURL)
        
        // Handle conflicts
        var conflictsResolved = 0
        if !syncResponse.conflicts.isEmpty {
            conflictsResolved = try await handleConflicts(syncResponse.conflicts)
        }
        
        // Apply remote changes
        try await applyRemoteChanges(syncResponse.changes)
        
        // Update vector clock and cursor
        vectorClock.merge(with: syncResponse.vectorClock)
        cursor = syncResponse.cursor
        
        // Save sync metadata
        try await localStorage.updateSyncMetadata(vectorClock: vectorClock, cursor: cursor)
        
        // Clear pending changes
        try await localStorage.clearPendingChanges()
        
        let duration = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
        
        return SyncResult(
            entitiesSynced: syncResponse.syncStats.entitiesSynced,
            relationshipsSynced: syncResponse.syncStats.relationshipsSynced,
            conflictsResolved: conflictsResolved,
            duration: duration
        )
    }
    
    /// Perform full sync
    public func fullSync(userId: String) async throws -> SyncResult {
        guard !isSyncing else {
            throw WildthingError.syncFailed("Sync already in progress")
        }
        
        guard let serverURL = configuration.serverURL else {
            throw WildthingError.networkError("Server URL not configured")
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let startTime = Date()
        
        // Clear local data
        try await localStorage.clearAll()
        
        // Reset sync metadata
        vectorClock = VectorClock()
        cursor = nil
        
        // Build full sync request
        let syncRequest = SyncRequest(
            deviceId: deviceId,
            userId: userId,
            syncType: .full,
            vectorClock: VectorClock(),
            changes: []
        )
        
        // Send sync request
        let syncResponse = try await sendSyncRequest(syncRequest, to: serverURL)
        
        // Apply all remote changes
        try await applyRemoteChanges(syncResponse.changes)
        
        // Update vector clock and cursor
        vectorClock = syncResponse.vectorClock
        cursor = syncResponse.cursor
        
        // Save sync metadata
        try await localStorage.updateSyncMetadata(vectorClock: vectorClock, cursor: cursor)
        
        let duration = Date().timeIntervalSince(startTime) * 1000
        
        return SyncResult(
            entitiesSynced: syncResponse.syncStats.entitiesSynced,
            relationshipsSynced: syncResponse.syncStats.relationshipsSynced,
            conflictsResolved: 0,
            duration: duration
        )
    }
    
    /// Stop any ongoing sync
    public func stop() {
        isSyncing = false
    }
    
    /// Check if currently syncing
    public var isSyncInProgress: Bool {
        return isSyncing
    }
    
    // MARK: - Private Methods
    
    private func loadSyncMetadata() async {
        do {
            let metadata = try await localStorage.getSyncMetadata()
            self.vectorClock = metadata.vectorClock
            self.cursor = metadata.cursor
        } catch {
            // Ignore errors loading metadata, will use defaults
        }
    }
    
    private func sendSyncRequest(_ request: SyncRequest, to serverURL: URL) async throws -> SyncResponse {
        let url = serverURL.appendingPathComponent("/api/sync")
        var urlRequest = authManager.authenticatedRequest(for: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 60 // Longer timeout for sync
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WildthingError.networkError("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(SyncResponse.self, from: data)
            
        case 401:
            throw WildthingError.authenticationRequired
            
        case 409:
            // Conflict response, parse and handle
            let conflictResponse = try JSONDecoder().decode(SyncResponse.self, from: data)
            return conflictResponse
            
        case 500...599:
            throw WildthingError.serverError(httpResponse.statusCode, "Server error")
            
        default:
            throw WildthingError.syncFailed("Unexpected status: \(httpResponse.statusCode)")
        }
    }
    
    private func handleConflicts(_ conflicts: [ConflictInfo]) async throws -> Int {
        let resolver = ConflictResolver()
        var resolvedCount = 0
        
        for conflict in conflicts {
            // Get local entity
            guard let localEntity = try await localStorage.getEntity(id: conflict.entityId) else {
                continue
            }
            
            // Fetch remote entity
            guard let remoteEntity = try await fetchRemoteEntity(id: conflict.entityId) else {
                continue
            }
            
            // Resolve conflict
            let resolvedEntity = resolver.resolve(
                local: localEntity,
                remote: remoteEntity,
                strategy: conflict.resolutionStrategy
            )
            
            // Update local storage with resolved entity
            try await localStorage.updateEntity(resolvedEntity)
            resolvedCount += 1
        }
        
        return resolvedCount
    }
    
    private func fetchRemoteEntity(id: String) async throws -> Entity? {
        guard let serverURL = configuration.serverURL else {
            return nil
        }
        
        let url = serverURL.appendingPathComponent("/api/entities/\(id)")
        let request = authManager.authenticatedRequest(for: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }
        
        if httpResponse.statusCode == 404 {
            return nil
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WildthingError.networkError("Failed to fetch entity: \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(Entity.self, from: data)
    }
    
    private func applyRemoteChanges(_ changes: [SyncChange]) async throws {
        for change in changes {
            switch change.changeType {
            case .create:
                if let entityChange = change.entity,
                   let entity = entityChange.toEntity() {
                    try await localStorage.createEntity(entity)
                }
                
                for relationshipChange in change.relationships {
                    if let relationship = relationshipChange.toRelationship() {
                        try await localStorage.createRelationship(relationship)
                    }
                }
                
            case .update:
                if let entityChange = change.entity,
                   let entity = entityChange.toEntity() {
                    try await localStorage.updateEntity(entity)
                }
                
                for relationshipChange in change.relationships {
                    if let relationship = relationshipChange.toRelationship() {
                        // For relationships, delete old and create new
                        try await localStorage.deleteRelationship(id: relationship.id)
                        try await localStorage.createRelationship(relationship)
                    }
                }
                
            case .delete:
                if let entityChange = change.entity {
                    try await localStorage.deleteEntity(id: entityChange.id)
                }
                
                for relationshipChange in change.relationships {
                    try await localStorage.deleteRelationship(id: relationshipChange.id)
                }
            }
        }
    }
}