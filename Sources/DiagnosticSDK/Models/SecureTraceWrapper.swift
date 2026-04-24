import Foundation

/// Container for encrypted trace exports.
public struct SecureTraceWrapper: Codable, Sendable, Equatable {
    public let isEncrypted: Bool
    public let salt: String
    public let encryptedData: String
    
    public init(isEncrypted: Bool, salt: String, encryptedData: String) {
        self.isEncrypted = isEncrypted
        self.salt = salt
        self.encryptedData = encryptedData
    }
}
