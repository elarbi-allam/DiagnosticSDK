import Foundation

/// Represents an HTTP request captured by the SDK
public struct RequestModel: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    
    /// I added this to track which screen triggered the network request.
    /// It's optional because background requests might occur before any screen is visible.
    public let screenName: String?
    
    public init(url: String, method: String, headers: [String: String], body: String?, screenName: String? = nil) {
            self.url = url
            self.method = method
            self.headers = headers
            self.body = body
            self.screenName = screenName
        }
}