import Foundation

/// Errors that can occur in the Wildthing client
public enum WildthingError: LocalizedError {
    case notConnected
    case authenticationRequired
    case authenticationFailed(String)
    case syncFailed(String)
    case conflictResolutionFailed(String)
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
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
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
    
    public var recoverySuggestion: String? {
        switch self {
        case .notConnected:
            return "Please connect to the server first"
        case .authenticationRequired, .authenticationFailed:
            return "Please check your credentials and try again"
        case .syncFailed:
            return "Check your network connection and try again"
        case .conflictResolutionFailed:
            return "Manual conflict resolution may be required"
        case .storageError:
            return "Check available storage space and permissions"
        case .networkError:
            return "Check your network connection"
        case .invalidData:
            return "Data format is invalid, please report this issue"
        case .serverError:
            return "Server issue, please try again later"
        }
    }
}