import Foundation

/// Represents an HTTP request
public struct RequestModel: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    
    public init(url: String, method: String, headers: [String: String], body: String?) {
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
        }
}
