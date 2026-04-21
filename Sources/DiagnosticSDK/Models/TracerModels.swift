import Foundation
import UIKit

// MARK: - Session Root

/// The root object representing a complete diagnostic tracing session.
public struct SessionTrace: Codable {
    public let sessionId: String
    public let startedAt: Date
    public let metadata: TraceMetadata
    public var screens: [ScreenNode]
    
    public init() {
        self.sessionId = UUID().uuidString
        self.startedAt = Date()
        self.metadata = TraceMetadata.current()
        self.screens = []
    }
}

// MARK: - Device Metadata

/// Device and application context for the captured session.
public struct TraceMetadata: Codable {
    public let appVersion: String
    public let osVersion: String
    public let deviceModel: String
    
    /// Generates metadata based on current device and bundle information.
    public static func current() -> TraceMetadata {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let osVersion = UIDevice.current.systemVersion
        
        // Hardware identifier (for example, "iPhone14,2").
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { ptr in String(validatingUTF8: ptr) }
        } ?? UIDevice.current.model
        
        return TraceMetadata(appVersion: appVersion, osVersion: osVersion, deviceModel: modelCode)
    }
}

// MARK: - Screen Tracking

/// Represents an active screen.
/// Implemented as a reference type to support in-place interaction appends.
public final class ScreenNode: Codable {
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
    /// Screen that was active when the request started (same semantics as `RequestModel.screenName`).
    public let screenName: String?
    public let request: RequestDetails
    public var response: ResponseDetails?
    
    public init(id: String = UUID().uuidString, request: RequestDetails, screenName: String? = nil) {
        self.id = id
        self.startedAt = Date()
        self.request = request
        self.screenName = screenName
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
