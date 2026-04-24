import Foundation
import CryptoKit

enum TraceEncryptionService {
    private static let saltLength = 16
    private static let hkdfInfo = Data("com.diagnosticsdk.trace-encryption".utf8)
    
    static func encryptTraceJSON(_ plainJSONData: Data, password: String) throws -> SecureTraceWrapper {
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else {
            throw TraceEncryptionServiceError.emptyPassword
        }
        
        let salt = randomSalt()
        let key = deriveKey(password: normalizedPassword, salt: salt)
        let sealedBox = try AES.GCM.seal(plainJSONData, using: key)
        
        guard let combined = sealedBox.combined else {
            throw TraceEncryptionServiceError.combinedCiphertextUnavailable
        }
        
        return SecureTraceWrapper(
            isEncrypted: true,
            salt: salt.base64EncodedString(),
            encryptedData: combined.base64EncodedString()
        )
    }
    
    static func decryptWrappedTrace(_ wrapper: SecureTraceWrapper, password: String) throws -> Data {
        guard wrapper.isEncrypted else {
            throw TraceEncryptionServiceError.wrapperNotEncrypted
        }
        
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPassword.isEmpty else {
            throw TraceEncryptionServiceError.emptyPassword
        }
        
        guard let saltData = Data(base64Encoded: wrapper.salt) else {
            throw TraceEncryptionServiceError.invalidSaltEncoding
        }
        
        guard let encryptedData = Data(base64Encoded: wrapper.encryptedData) else {
            throw TraceEncryptionServiceError.invalidEncryptedDataEncoding
        }
        
        let key = deriveKey(password: normalizedPassword, salt: saltData)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw TraceEncryptionServiceError.decryptionFailed
        }
    }
    
    private static func randomSalt() -> Data {
        Data((0..<saltLength).map { _ in UInt8.random(in: 0...255) })
    }
    
    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let inputKey = SymmetricKey(data: passwordData)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: hkdfInfo,
            outputByteCount: 32
        )
    }
}

enum TraceEncryptionServiceError: LocalizedError {
    case emptyPassword
    case wrapperNotEncrypted
    case invalidSaltEncoding
    case invalidEncryptedDataEncoding
    case combinedCiphertextUnavailable
    case decryptionFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyPassword:
            return "Password cannot be empty."
        case .wrapperNotEncrypted:
            return "File is not marked as encrypted."
        case .invalidSaltEncoding:
            return "Encrypted file has an invalid salt value."
        case .invalidEncryptedDataEncoding:
            return "Encrypted file has an invalid payload value."
        case .combinedCiphertextUnavailable:
            return "Unable to produce encrypted payload."
        case .decryptionFailed:
            return "Unable to decrypt payload. Password may be incorrect or file may be corrupted."
        }
    }
}
