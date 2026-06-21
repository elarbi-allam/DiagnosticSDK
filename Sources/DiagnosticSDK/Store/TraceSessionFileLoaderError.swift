import Foundation

enum TraceSessionFileLoaderError: LocalizedError {
    case fileReadFailed
    case unsupportedFormat
    case invalidEncryptedFile
    case wrongPasswordOrCorruptedFile
    /// Encrypted trace on disk; caller must obtain a password and retry.
    case passwordRequired

    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "Unable to read this trace file."
        case .unsupportedFormat:
            return "Unsupported trace file format."
        case .invalidEncryptedFile:
            return "Encrypted trace file is invalid or corrupted."
        case .wrongPasswordOrCorruptedFile:
            return "Unable to decrypt trace. Password may be incorrect or file may be corrupted."
        case .passwordRequired:
            return "This trace is encrypted. Enter the password to continue."
        }
    }
}
