import XCTest
@testable import Wildthing

final class AuthManagerTests: XCTestCase {
    
    var authManager: AuthManager!
    var configuration: Configuration!
    
    override func setUp() {
        super.setUp()
        configuration = Configuration()
        authManager = AuthManager(configuration: configuration)
    }
    
    override func tearDown() async throws {
        await authManager.clearToken()
        authManager = nil
        configuration = nil
        try await super.tearDown()
    }
    
    func testSetAndGetToken() async throws {
        let testToken = "test-jwt-token-12345"
        
        try await authManager.setToken(testToken)
        let retrievedToken = authManager.getToken()
        
        XCTAssertEqual(retrievedToken, testToken)
    }
    
    func testClearToken() async throws {
        let testToken = "test-jwt-token"
        
        try await authManager.setToken(testToken)
        XCTAssertNotNil(authManager.getToken())
        
        await authManager.clearToken()
        XCTAssertNil(authManager.getToken())
    }
    
    func testIsAuthenticated() async throws {
        XCTAssertFalse(authManager.isAuthenticated())
        
        try await authManager.setToken("test-token")
        XCTAssertTrue(authManager.isAuthenticated())
        
        await authManager.clearToken()
        XCTAssertFalse(authManager.isAuthenticated())
    }
    
    func testAuthenticatedRequest() async throws {
        let testToken = "test-jwt-token"
        try await authManager.setToken(testToken)
        
        let url = URL(string: "https://example.com/api/test")!
        let request = authManager.authenticatedRequest(for: url)
        
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(testToken)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))
    }
    
    func testTokenPersistence() async throws {
        let testToken = "persistent-token"
        
        // Create first auth manager and set token
        let authManager1 = AuthManager(configuration: configuration)
        try await authManager1.setToken(testToken)
        
        // Create second auth manager and check if token persists
        let authManager2 = AuthManager(configuration: configuration)
        let retrievedToken = authManager2.getToken()
        
        XCTAssertEqual(retrievedToken, testToken)
        
        // Clean up
        await authManager2.clearToken()
    }
}