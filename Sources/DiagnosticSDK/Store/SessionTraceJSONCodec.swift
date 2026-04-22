import Foundation

enum SessionTraceJSONCodec {
    
    static func encode(_ session: SessionTrace) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(session)
        } catch {
            throw SessionTraceJSONCodecError.encodingFailed(details: describeEncodingError(error))
        }
    }
    
    static func decode(from data: Data) throws -> SessionTrace {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(SessionTrace.self, from: data)
        } catch {
            throw SessionTraceJSONCodecError.decodingFailed(details: describeDecodingError(error))
        }
    }
    
    static func decodeFile(at fileURL: URL) throws -> SessionTrace {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw SessionTraceJSONCodecError.fileReadFailed(
                url: fileURL,
                details: error.localizedDescription
            )
        }
        
        return try decode(from: data)
    }
    
    private static func describeEncodingError(_ error: Error) -> String {
        guard let encodingError = error as? EncodingError else {
            return error.localizedDescription
        }
        
        switch encodingError {
        case .invalidValue(let value, let context):
            return "Invalid value '\(value)' at path '\(codingPath(from: context.codingPath))': \(context.debugDescription)"
        @unknown default:
            return encodingError.localizedDescription
        }
    }
    
    private static func describeDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        
        switch decodingError {
        case .typeMismatch(let type, let context):
            return "Type mismatch for '\(type)' at path '\(codingPath(from: context.codingPath))': \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing value for '\(type)' at path '\(codingPath(from: context.codingPath))': \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at path '\(codingPath(from: context.codingPath))': \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Corrupted data at path '\(codingPath(from: context.codingPath))': \(context.debugDescription)"
        @unknown default:
            return decodingError.localizedDescription
        }
    }
    
    private static func codingPath(from path: [CodingKey]) -> String {
        let formattedPath = path.map(\.stringValue).joined(separator: ".")
        return formattedPath.isEmpty ? "root" : formattedPath
    }
}

enum SessionTraceJSONCodecError: LocalizedError {
    case fileReadFailed(url: URL, details: String)
    case encodingFailed(details: String)
    case decodingFailed(details: String)
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let details):
            return "Failed to read session file at '\(url.path)': \(details)"
        case .encodingFailed(let details):
            return "Failed to encode SessionTrace to JSON: \(details)"
        case .decodingFailed(let details):
            return "Failed to decode SessionTrace from JSON: \(details)"
        }
    }
}
