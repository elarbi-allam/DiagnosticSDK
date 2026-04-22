import Foundation

enum JSONFormatter {
    
    static func format(event: NetworkEvent) -> String? {
        do {
            return try formattedString(from: event)
        } catch let error as JSONFormatterError {
            print("[DiagnosticSDK][JSONFormatter] \(error.localizedDescription)")
            return nil
        } catch {
            print("[DiagnosticSDK][JSONFormatter] Unexpected formatting error: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func formattedString(from event: NetworkEvent) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data: Data
        do {
            data = try encoder.encode(event)
        } catch {
            throw JSONFormatterError.encodingFailure(details: describeEncodingError(error))
        }
        
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw JSONFormatterError.invalidUTF8
        }
        
        return jsonString
    }
    
    static func decodeEvent(from jsonString: String) throws -> NetworkEvent {
        guard let data = jsonString.data(using: .utf8) else {
            throw JSONFormatterError.invalidUTF8
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(NetworkEvent.self, from: data)
        } catch {
            throw JSONFormatterError.decodingFailure(details: describeDecodingError(error))
        }
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

enum JSONFormatterError: LocalizedError {
    case encodingFailure(details: String)
    case decodingFailure(details: String)
    case invalidUTF8
    
    var errorDescription: String? {
        switch self {
        case .encodingFailure(let details):
            return "Encoding failed: \(details)"
        case .decodingFailure(let details):
            return "Decoding failed: \(details)"
        case .invalidUTF8:
            return "UTF-8 conversion failed while processing JSON payload."
        }
    }
}
