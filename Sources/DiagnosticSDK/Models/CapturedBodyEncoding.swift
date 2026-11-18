import Foundation

public enum CapturedBodyEncoding: String, Codable, Sendable {
    case text
    case base64
}

public enum CapturedBodyOmission: String, Codable, Sendable {
    case binaryContent
    case memoryBudget
}
