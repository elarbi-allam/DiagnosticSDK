import Foundation

/// Represents an HTTP request captured by the SDK
public struct RequestModel: Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let bodySizeBytes: Int?
    public let bodyEncoding: CapturedBodyEncoding?
    public let isBodyTruncated: Bool?
    public let bodyOmission: CapturedBodyOmission?
    
    /// Screen associated with the request at dispatch time.
    public let screenName: String?
    
    /// Unique visit identifier of the screen at dispatch time.
    public let screenVisitId: Int?
    
    public init(
        url: String,
        method: String,
        headers: [String: String],
        body: String?,
        screenName: String? = nil,
        screenVisitId: Int? = nil,
        bodySizeBytes: Int? = nil,
        bodyEncoding: CapturedBodyEncoding? = nil,
        isBodyTruncated: Bool? = nil,
        bodyOmission: CapturedBodyOmission? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.screenName = screenName
        self.screenVisitId = screenVisitId
        self.bodySizeBytes = bodySizeBytes
        self.bodyEncoding = bodyEncoding
        self.isBodyTruncated = isBodyTruncated
        self.bodyOmission = bodyOmission
    }
}
