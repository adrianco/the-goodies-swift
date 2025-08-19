# Bertha Test App Implementation Plan

## Overview
Detailed implementation plan for the Bertha SwiftUI test application that demonstrates the functionality of Wildthing and Inbetweenies packages.

## App Structure
```
bertha/
├── bertha/
│   ├── App/
│   │   ├── BerthaApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── ConnectionView.swift
│   │   ├── EntityListView.swift
│   │   ├── EntityDetailView.swift
│   │   ├── RelationshipView.swift
│   │   ├── SyncStatusView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/
│   │   ├── AppViewModel.swift
│   │   ├── ConnectionViewModel.swift
│   │   ├── EntityViewModel.swift
│   │   └── SyncViewModel.swift
│   ├── Components/
│   │   ├── EntityCard.swift
│   │   ├── RelationshipGraph.swift
│   │   ├── SyncIndicator.swift
│   │   └── ErrorAlert.swift
│   ├── Models/
│   │   └── AppModels.swift
│   ├── Services/
│   │   └── AppServices.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   └── Info.plist
│   └── Preview Content/
│       └── Preview Assets.xcassets/
├── berthaTests/
│   ├── ViewModelTests/
│   ├── ServiceTests/
│   └── IntegrationTests/
└── berthaUITests/
    └── UITests.swift
```

## Implementation Details

### 1. App Module

#### BerthaApp.swift
```swift
import SwiftUI
import Wildthing

@main
struct BerthaApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @State private var showingOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
                .onAppear {
                    checkFirstLaunch()
                }
                .sheet(isPresented: $showingOnboarding) {
                    OnboardingView()
                }
        }
    }
    
    private func checkFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            showingOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}
```

### 2. Views Module

#### ContentView.swift
```swift
import SwiftUI
import Wildthing
import Inbetweenies

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            // Entities Tab
            EntityListView()
                .tabItem {
                    Label("Entities", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            // Graph Tab
            GraphView()
                .tabItem {
                    Label("Graph", systemImage: "network")
                }
                .tag(2)
            
            // Sync Tab
            SyncView()
                .tabItem {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(3)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .overlay(alignment: .top) {
            if appViewModel.isSyncing {
                SyncIndicator()
                    .padding(.top, 50)
            }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    ConnectionStatusCard()
                    
                    // Quick Stats
                    StatsGrid()
                    
                    // Recent Activity
                    RecentActivityList()
                    
                    // Quick Actions
                    QuickActionsGrid()
                }
                .padding()
            }
            .navigationTitle("Bertha")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await appViewModel.refresh() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}
```

#### ConnectionView.swift
```swift
import SwiftUI
import Wildthing

struct ConnectionView: View {
    @StateObject private var viewModel = ConnectionViewModel()
    @State private var serverURL = ""
    @State private var clientId = ""
    @State private var password = ""
    @State private var authToken = ""
    @State private var useToken = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("Use Authentication Token", isOn: $useToken)
                }
                
                if useToken {
                    Section("Token Authentication") {
                        SecureField("Auth Token", text: $authToken)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Section("Password Authentication") {
                        TextField("Client ID", text: $clientId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Section {
                    Button(action: connect) {
                        HStack {
                            if viewModel.isConnecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isConnecting || serverURL.isEmpty)
                    
                    if viewModel.isConnected {
                        Button(action: disconnect) {
                            Text("Disconnect")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                if viewModel.isConnected {
                    Section("Connection Info") {
                        LabeledContent("Status", value: "Connected")
                        LabeledContent("Device ID", value: viewModel.deviceId)
                        if let lastSync = viewModel.lastSyncDate {
                            LabeledContent("Last Sync", value: lastSync.formatted())
                        }
                    }
                }
            }
            .navigationTitle("Connection")
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func connect() {
        Task {
            do {
                if useToken {
                    try await viewModel.connect(
                        serverURL: serverURL,
                        authToken: authToken
                    )
                } else {
                    try await viewModel.connect(
                        serverURL: serverURL,
                        clientId: clientId,
                        password: password
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func disconnect() {
        Task {
            await viewModel.disconnect()
        }
    }
}
```

#### EntityListView.swift
```swift
import SwiftUI
import Inbetweenies
import Wildthing

struct EntityListView: View {
    @StateObject private var viewModel = EntityViewModel()
    @State private var selectedEntityType: EntityType?
    @State private var searchText = ""
    @State private var showingCreateSheet = false
    @State private var showingFilterSheet = false
    
    var filteredEntities: [Entity] {
        viewModel.entities.filter { entity in
            (selectedEntityType == nil || entity.entityType == selectedEntityType) &&
            (searchText.isEmpty || entity.name.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty && filteredEntities.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No entities found matching '\(searchText)'")
                    )
                } else {
                    ForEach(filteredEntities) { entity in
                        NavigationLink(destination: EntityDetailView(entity: entity)) {
                            EntityRow(entity: entity)
                        }
                    }
                    .onDelete(perform: deleteEntities)
                }
            }
            .searchable(text: $searchText, prompt: "Search entities")
            .navigationTitle("Entities")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateEntityView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterView(selectedType: $selectedEntityType)
            }
            .refreshable {
                await viewModel.loadEntities()
            }
            .onAppear {
                Task {
                    await viewModel.loadEntities()
                }
            }
        }
    }
    
    private func deleteEntities(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let entity = filteredEntities[index]
                try await viewModel.deleteEntity(entity.id)
            }
        }
    }
}

struct EntityRow: View {
    let entity: Entity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entity.name)
                    .font(.headline)
                Spacer()
                EntityTypeBadge(type: entity.entityType)
            }
            
            Text("Version: \(String(entity.version.prefix(8)))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !entity.content.isEmpty {
                Text("\(entity.content.count) properties")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EntityTypeBadge: View {
    let type: EntityType
    
    var color: Color {
        switch type {
        case .home: return .blue
        case .room: return .green
        case .device: return .orange
        case .zone: return .purple
        case .procedure: return .pink
        case .automation: return .red
        default: return .gray
        }
    }
    
    var icon: String {
        switch type {
        case .home: return "house"
        case .room: return "door.left.hand.open"
        case .device: return "tv"
        case .zone: return "square.dashed"
        case .procedure: return "list.bullet"
        case .automation: return "gearshape.2"
        default: return "square"
        }
    }
    
    var body: some View {
        Label(type.rawValue.capitalized, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
```

### 3. ViewModels Module

#### AppViewModel.swift
```swift
import SwiftUI
import Combine
import Wildthing
import Inbetweenies

@MainActor
class AppViewModel: ObservableObject {
    @Published var client: WildthingClient
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var pendingChanges = 0
    @Published var entities: [Entity] = []
    @Published var relationships: [EntityRelationship] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let configuration = Configuration(
            autoSync: true,
            syncInterval: 300,
            debugMode: true
        )
        
        self.client = WildthingClient(configuration: configuration)
        
        setupBindings()
    }
    
    private func setupBindings() {
        client.$isConnected
            .assign(to: &$isConnected)
        
        client.$isSyncing
            .assign(to: &$isSyncing)
        
        client.$syncStatus
            .assign(to: &$syncStatus)
        
        client.$lastSyncDate
            .assign(to: &$lastSyncDate)
        
        client.$pendingChangesCount
            .assign(to: &$pendingChanges)
    }
    
    func connect(serverURL: String, authToken: String? = nil, clientId: String? = nil, password: String? = nil) async throws {
        guard let url = URL(string: serverURL) else {
            throw WildthingError.invalidData("Invalid server URL")
        }
        
        try await client.connect(
            serverURL: url,
            authToken: authToken,
            clientId: clientId,
            password: password
        )
        
        await loadData()
    }
    
    func disconnect() async {
        await client.disconnect()
        entities = []
        relationships = []
    }
    
    func sync() async throws {
        _ = try await client.sync()
        await loadData()
    }
    
    func refresh() async {
        await loadData()
    }
    
    private func loadData() async {
        do {
            entities = try await client.listEntities()
            
            // Load relationships for all entities
            relationships = []
            for entity in entities {
                let entityRelationships = try await client.getRelationships(for: entity.id)
                relationships.append(contentsOf: entityRelationships)
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}
```

#### EntityViewModel.swift
```swift
import SwiftUI
import Combine
import Wildthing
import Inbetweenies

@MainActor
class EntityViewModel: ObservableObject {
    @Published var entities: [Entity] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var client: WildthingClient?
    
    init() {
        // Get client from app view model if available
    }
    
    func setClient(_ client: WildthingClient) {
        self.client = client
    }
    
    func loadEntities(type: EntityType? = nil) async {
        guard let client = client else { return }
        
        isLoading = true
        error = nil
        
        do {
            entities = try await client.listEntities(type: type)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func createEntity(
        type: EntityType,
        name: String,
        content: [String: Any] = [:]
    ) async throws {
        guard let client = client else { return }
        
        let entity = Entity(
            id: UUID().uuidString,
            version: UUID().uuidString,
            entityType: type,
            name: name,
            content: content.mapValues { AnyCodable($0) },
            sourceType: .manual,
            userId: nil,
            parentVersions: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await client.createEntity(entity)
        await loadEntities()
    }
    
    func updateEntity(_ entity: Entity) async throws {
        guard let client = client else { return }
        
        try await client.updateEntity(entity)
        await loadEntities()
    }
    
    func deleteEntity(_ id: String) async throws {
        guard let client = client else { return }
        
        try await client.deleteEntity(id: id)
        await loadEntities()
    }
    
    func getRelationships(for entityId: String) async throws -> [EntityRelationship] {
        guard let client = client else { return [] }
        
        return try await client.getRelationships(for: entityId)
    }
    
    func createRelationship(
        from: String,
        to: String,
        type: RelationshipType
    ) async throws {
        guard let client = client else { return }
        
        // Get entity versions
        guard let fromEntity = try await client.getEntity(id: from),
              let toEntity = try await client.getEntity(id: to) else {
            throw WildthingError.invalidData("Entity not found")
        }
        
        let relationship = EntityRelationship(
            id: UUID().uuidString,
            fromEntityId: from,
            fromEntityVersion: fromEntity.version,
            toEntityId: to,
            toEntityVersion: toEntity.version,
            relationshipType: type,
            properties: [:],
            userId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        try await client.createRelationship(relationship)
    }
}
```

### 4. Components Module

#### SyncIndicator.swift
```swift
import SwiftUI

struct SyncIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            Text("Syncing...")
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.blue.opacity(0.2))
        )
        .onAppear {
            isAnimating = true
        }
    }
}
```

#### EntityCard.swift
```swift
import SwiftUI
import Inbetweenies

struct EntityCard: View {
    let entity: Entity
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForEntityType(entity.entityType))
                    .font(.title2)
                    .foregroundColor(colorForEntityType(entity.entityType))
                
                Spacer()
                
                Text(entity.entityType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(colorForEntityType(entity.entityType).opacity(0.2))
                    )
            }
            
            Text(entity.name)
                .font(.headline)
                .lineLimit(1)
            
            if !entity.content.isEmpty {
                Text("\(entity.content.count) properties")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Updated")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(entity.updatedAt.formatted(.relative(presentation: .abbreviated)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .onTapGesture(perform: onTap)
    }
    
    private func iconForEntityType(_ type: EntityType) -> String {
        switch type {
        case .home: return "house.fill"
        case .room: return "door.left.hand.open"
        case .device: return "tv.fill"
        case .zone: return "square.dashed"
        case .procedure: return "list.bullet"
        case .automation: return "gearshape.2.fill"
        default: return "square.fill"
        }
    }
    
    private func colorForEntityType(_ type: EntityType) -> Color {
        switch type {
        case .home: return .blue
        case .room: return .green
        case .device: return .orange
        case .zone: return .purple
        case .procedure: return .pink
        case .automation: return .red
        default: return .gray
        }
    }
}
```

## Testing Plan

### Unit Tests
- ViewModel logic testing
- Service layer testing
- Model serialization
- UI component testing

### UI Tests
- Connection flow
- Entity CRUD operations
- Sync status updates
- Navigation flows
- Error handling

### Integration Tests
- End-to-end sync scenarios
- Offline operation
- Conflict resolution UI
- Performance testing

## Features to Implement

### Phase 1: Core Functionality
1. Connection management
2. Entity list and detail views
3. Basic sync status
4. Settings screen

### Phase 2: Advanced Features
1. Relationship visualization
2. Graph view with interactive nodes
3. Conflict resolution UI
4. MCP tool execution

### Phase 3: Polish
1. Animations and transitions
2. Dark mode support
3. iPad optimization
4. Widget extension

## Success Metrics
1. Successfully connects to FunkyGibbon server
2. Displays entities and relationships
3. Shows real-time sync status
4. Handles offline mode gracefully
5. Provides intuitive navigation
6. Responsive UI with smooth animations
7. Proper error handling and recovery
8. Memory efficient with large datasets