import Foundation

/// Represents an HTTP request captured by the SDK
public struct RequestModel: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    
    /// Screen associated with the request at dispatch time.
    public let screenName: String?
    
    public init(url: String, method: String, headers: [String: String], body: String?, screenName: String? = nil) {
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
            self.screenName = screenName
        }
}