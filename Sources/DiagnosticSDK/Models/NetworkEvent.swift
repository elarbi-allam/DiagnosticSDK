import Foundation

/// Complete event (request + response)
public struct NetworkEvent: Codable {
    public let request: RequestModel
    public let response: ResponseModel?
    public let timestamp: Date
    public let sessionId: String
    public let sessionStartedAt: Date
    
    public init(
        request: RequestModel,
        response: ResponseModel?,
        timestamp: Date,
        sessionId: String,
        sessionStartedAt: Date
    ) {
            self.request = request
            self.response = response
            self.timestamp = timestamp
            self.sessionId = sessionId
            self.sessionStartedAt = sessionStartedAt
    }

    enum CodingKeys: String, CodingKey {
        case request
        case response
        case timestamp
        case sessionId
        case sessionStartedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        request = try container.decode(RequestModel.self, forKey: .request)
        response = try container.decodeIfPresent(ResponseModel.self, forKey: .response)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId) ?? "legacy-session"
        sessionStartedAt = try container.decodeIfPresent(Date.self, forKey: .sessionStartedAt) ?? timestamp
    }
}

