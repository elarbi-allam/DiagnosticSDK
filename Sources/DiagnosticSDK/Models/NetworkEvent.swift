import Foundation

/// Complete event (request + response)
public struct NetworkEvent: Codable {
    public let request: RequestModel
    public let response: ResponseModel?
    public let timestamp: Date
    public let durationMs: Int?
    public let captureId: String?
    public let startedAt: Date?
    public let timing: NetworkTiming?
    public var isMocked: Bool = false
    
    private enum CodingKeys: String, CodingKey {
        case request
        case response
        case timestamp
        case durationMs
        case captureId
        case startedAt
        case timing
    }
    
    public init(
        request: RequestModel,
        response: ResponseModel?,
        timestamp: Date,
        durationMs: Int? = nil,
        captureId: String? = nil,
        startedAt: Date? = nil,
        timing: NetworkTiming? = nil,
        isMocked: Bool = false
    ) {
            self.request = request
            self.response = response
            self.timestamp = timestamp
            self.durationMs = durationMs
            self.captureId = captureId
            self.startedAt = startedAt
            self.timing = timing
            self.isMocked = isMocked
    }
}

