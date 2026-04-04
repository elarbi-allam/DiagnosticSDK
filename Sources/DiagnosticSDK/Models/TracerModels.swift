import Foundation

/// Racine de la session exportée
public struct SessionTrace: Codable {
    public let sessionId: String
    public let startTime: Date
    public var nodes: [ViewNode]
    
    public init() {
        self.sessionId = UUID().uuidString
        self.startTime = Date()
        self.nodes = []
    }
}

/// Nœud UI (Tracer d'écrans)
public class ViewNode: Codable {
    public let id: String
    public let viewName: String
    public let enteredAt: Date
    public var exitedAt: Date?
    public var requests: [NetworkInteraction]
    
    public init(viewName: String) {
        self.id = UUID().uuidString
        self.viewName = viewName
        self.enteredAt = Date()
        self.requests = []
    }
}

/// Événement Réseau (Tracer Réseau)
public struct NetworkInteraction: Codable {
    public let id: String
    public let timestamp: Date
    public let request: RequestDetails
    public var response: ResponseDetails?
    public var durationMs: Int?
    
    public init(request: RequestDetails) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.request = request
    }
}

public struct RequestDetails: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]?
    public let body: String?
}

public struct ResponseDetails: Codable {
    public let statusCode: Int
    public let headers: [String: String]?
    public let body: String?
}
