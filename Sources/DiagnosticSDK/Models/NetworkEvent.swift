import Foundation

/// Complete event (request + response)
public struct NetworkEvent: Codable {
    public let request: RequestModel
    public let response: ResponseModel?
    public let timestamp: Date
    
    public init(request: RequestModel, response: ResponseModel?, timestamp: Date) {
            self.request = request
            self.response = response
            self.timestamp = timestamp
    }
}

