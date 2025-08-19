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