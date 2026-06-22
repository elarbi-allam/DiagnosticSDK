import Foundation

/// Complete event (request + response)
public struct NetworkEvent: Codable {
    public let request: RequestModel
    public let response: ResponseModel?
    public let timestamp: Date
    public let durationMs: Int?
    public var isMocked: Bool = false
    
    private enum CodingKeys: String, CodingKey {
        case request
        case response
        case timestamp
        case durationMs
    }
    
    public init(
        request: RequestModel,
        response: ResponseModel?,
        timestamp: Date,
        durationMs: Int? = nil,
        isMocked: Bool = false
    ) {
            self.request = request
            self.response = response
            self.timestamp = timestamp
            self.durationMs = durationMs
            self.isMocked = isMocked
    }
}

