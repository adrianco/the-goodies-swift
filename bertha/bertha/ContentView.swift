/**
 * File: ContentView.swift
 * Purpose: Main UI for Bertha test application
 * 
 * CONTEXT:
 * Bertha is a SwiftUI test application that demonstrates the usage of
 * Wildthing and Inbetweenies packages. It provides a user interface for
 * testing connection, synchronization, and entity management features.
 * 
 * FUNCTIONALITY:
 * - Tab-based navigation (Home, Connection, Entities, Settings)
 * - Server connection configuration UI
 * - Authentication with client ID and password
 * - Connection status display
 * - Entity listing and management (planned)
 * - Settings configuration (planned)
 * 
 * TESTING USAGE:
 * This app is designed for testing the Swift implementation against
 * a running FunkyGibbon server. Use the Connection tab to configure
 * and establish a connection to the server.
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial UI implementation
 * - Created by Adrian Cockcroft on 8/18/25.
 */

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)
            
            // Connection Tab
            ConnectionView()
                .tabItem {
                    Label("Connect", systemImage: "network")
                }
                .tag(1)
            
            // Entities Tab
            Text("Entities")
                .tabItem {
                    Label("Entities", systemImage: "square.grid.2x2")
                }
                .tag(2)
            
            // Settings Tab
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Bertha")
                    .font(.largeTitle)
                    .padding()
                
                Text("A test app for The Goodies Swift packages")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Bertha")
        }
    }
}

struct ConnectionView: View {
    @State private var serverURL = ""
    @State private var clientId = ""
    @State private var password = ""
    @State private var isConnected = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    TextField("Client ID", text: $clientId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("Password", text: $password)
                }
                
                Section {
                    Button(action: {
                        // Connect action will be implemented with Wildthing
                        isConnected.toggle()
                    }) {
                        Text(isConnected ? "Disconnect" : "Connect")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if isConnected {
                    Section("Status") {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Connection")
        }
    }
}

#Preview {
    ContentView()
}
