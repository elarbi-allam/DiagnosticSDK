import Foundation

public struct NetworkTiming: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable {
        case systemMetrics
        case clock
    }

    public struct Phases: Codable, Equatable, Sendable {
        public let domainLookupMs: Int?
        public let connectionMs: Int?
        public let secureConnectionMs: Int?
        public let requestSendMs: Int?
        public let serverWaitMs: Int?
        public let downloadMs: Int?
    }

    public let source: Source
    public let networkDurationMs: Int?
    public let appPerceivedDurationMs: Int
    public let phases: Phases?
    public let redirectCount: Int
    public let isServedFromCache: Bool
    public let networkProtocol: String?
    public let isConnectionReused: Bool?
    public let responseBytesReceived: Int64?

    public var preferredDurationMs: Int {
        networkDurationMs ?? appPerceivedDurationMs
    }
}
