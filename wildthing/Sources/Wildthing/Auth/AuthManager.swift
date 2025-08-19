/**
 * File: AuthManager.swift
 * Purpose: Authentication management for server connections
 * 
 * CONTEXT:
 * Handles authentication tokens and credentials for secure communication
 * with the FunkyGibbon server. Supports both token-based and password
 * authentication methods with secure Keychain storage.
 * 
 * FUNCTIONALITY:
 * - JWT token storage and management
 * - Password-based authentication flow
 * - Token refresh and expiration handling
 * - Secure credential storage in iOS/macOS Keychain
 * - Request signing with authentication headers
 * 
 * PYTHON PARITY:
 * Corresponds to auth functionality in Python blowing-off
 * - ✅ Token-based authentication
 * - ✅ Password authentication
 * - ✅ Request signing with Bearer tokens
 * - ✅ Secure token persistence
 * - ✅ JWT expiration validation
 * 
 * CHANGES:
 * - 2025-08-19: Added comprehensive documentation
 * - 2025-08-18: Initial authentication implementation with Keychain
 */

import Foundation
import Security

/// Authentication manager with secure token storage
public class AuthManager {
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let keychainService = "com.wildthing.auth"
    private let keychainAccount = "authToken"
    private var currentToken: String?
    private let queue = DispatchQueue(label: "wildthing.auth", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(configuration: Configuration) {
        self.configuration = configuration
        // Try to load token from keychain on init
        self.currentToken = loadTokenFromKeychain()
    }
    
    // MARK: - Public Methods
    
    /// Authenticate with server
    public func authenticate(
        clientId: String,
        password: String,
        serverURL: URL
    ) async throws -> String {
        // Create authentication request
        let authRequest = AuthRequest(
            clientId: clientId,
            password: password
        )
        
        var urlRequest = URLRequest(url: serverURL.appendingPathComponent("/api/auth"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(authRequest)
        urlRequest.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WildthingError.authenticationFailed("Invalid response")
        }
        
        switch httpResponse.statusCode {
        case 200:
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            try await setToken(authResponse.token)
            return authResponse.token
            
        case 401:
            throw WildthingError.authenticationFailed("Invalid credentials")
            
        case 403:
            throw WildthingError.authenticationFailed("Access forbidden")
            
        default:
            throw WildthingError.authenticationFailed("Status code: \(httpResponse.statusCode)")
        }
    }
    
    /// Set authentication token
    public func setToken(_ token: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: WildthingError.authenticationFailed("Auth manager deallocated"))
                    return
                }
                
                do {
                    try self.saveTokenToKeychain(token)
                    self.currentToken = token
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get current authentication token
    public func getToken() -> String? {
        queue.sync {
            if let token = currentToken {
                return token
            }
            currentToken = loadTokenFromKeychain()
            return currentToken
        }
    }
    
    /// Clear authentication token
    public func clearToken() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                self.deleteTokenFromKeychain()
                self.currentToken = nil
                continuation.resume()
            }
        }
    }
    
    /// Check if authenticated
    public func isAuthenticated() -> Bool {
        return getToken() != nil
    }
    
    /// Refresh token if needed
    public func refreshTokenIfNeeded() async throws {
        guard let token = getToken() else {
            throw WildthingError.authenticationRequired
        }
        
        // Parse JWT to check expiration
        if isTokenExpired(token) {
            throw WildthingError.authenticationRequired
        }
    }
    
    /// Build authenticated request
    public func authenticatedRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        if let token = getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Wildthing/\(Wildthing.version)", forHTTPHeaderField: "User-Agent")
        
        return request
    }
    
    // MARK: - Keychain Operations
    
    private func saveTokenToKeychain(_ token: String) throws {
        guard let tokenData = token.data(using: .utf8) else {
            throw WildthingError.authenticationFailed("Invalid token format")
        }
        
        // Delete existing token first
        deleteTokenFromKeychain()
        
        // Create keychain query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw WildthingError.authenticationFailed("Failed to save token to keychain: \(status)")
        }
    }
    
    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let tokenData = result as? Data,
              let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - JWT Validation
    
    private func isTokenExpired(_ token: String) -> Bool {
        // Simple JWT expiration check
        // In production, use a proper JWT library
        let components = token.split(separator: ".")
        guard components.count == 3 else { return true }
        
        let payload = components[1]
        guard let payloadData = base64URLDecode(String(payload)),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        
        return Date().timeIntervalSince1970 >= exp
    }
    
    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        
        return Data(base64Encoded: base64)
    }
}

// MARK: - Auth Models

/// Authentication request
struct AuthRequest: Codable {
    let clientId: String
    let password: String
    
    private enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case password
    }
}

/// Authentication response
struct AuthResponse: Codable {
    let token: String
    let expiresIn: Int?
    let tokenType: String?
    
    private enum CodingKeys: String, CodingKey {
        case token
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}