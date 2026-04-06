import Foundation

// MARK: - Session Root

/// The root object representing a complete diagnostic tracing session.
public struct SessionTrace: Codable {
    public let sessionId: String
    public let startedAt: Date
    public let metadata: TraceMetadata
    public var screens: [ScreenNode]
    
    public init(metadata: TraceMetadata) {
        self.sessionId = UUID().uuidString
        self.startedAt = Date()
        self.metadata = metadata
        self.screens = []
    }
}

/// Device and application context for the captured session.
public struct TraceMetadata: Codable {
    public let appVersion: String
    public let osVersion: String
    public let deviceModel: String
    
    public init(appVersion: String, osVersion: String, deviceModel: String) {
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.deviceModel = deviceModel
    }
}

// MARK: - Screen Tracking

/// Represents an active screen.
/// Implemented as a class (reference type) to allow appending network interactions
/// to the `networkInteractions` array while the screen is currently visible.
public class ScreenNode: Codable {
    public let id: String
    public let name: String
    public let enteredAt: Date
    public var exitedAt: Date?
    public var networkInteractions: [NetworkInteraction]
    
    public init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        self.enteredAt = Date()
        self.networkInteractions = []
    }
}

// MARK: - Network Tracking

/// Represents a single HTTP request/response lifecycle.
public struct NetworkInteraction: Codable {
    public let id: String
    public let startedAt: Date
    public var durationMs: Int?
    public let request: RequestDetails
    public var response: ResponseDetails?
    
    public init(request: RequestDetails) {
        self.id = UUID().uuidString
        self.startedAt = Date()
        self.request = request
    }
}

/// Details of the outgoing HTTP request.
public struct RequestDetails: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]?
    public let bodyBase64: String?
    public let bodySizeBytes: Int
    
    public init(url: String, method: String, headers: [String: String]?, bodyBase64: String?, bodySizeBytes: Int) {
        self.url = url
        self.method = method
        self.headers = headers
        self.bodyBase64 = bodyBase64
        self.bodySizeBytes = bodySizeBytes
    }
}

/// Details of the incoming HTTP response.
public struct ResponseDetails: Codable {
    public let status: Int
    public let headers: [String: String]?
    public let bodyBase64: String?
    public let bodySizeBytes: Int
    public let errorDescription: String?
    
    public init(status: Int, headers: [String: String]?, bodyBase64: String?, bodySizeBytes: Int, errorDescription: String?) {
        self.status = status
        self.headers = headers
        self.bodyBase64 = bodyBase64
        self.bodySizeBytes = bodySizeBytes
        self.errorDescription = errorDescription
    }
}