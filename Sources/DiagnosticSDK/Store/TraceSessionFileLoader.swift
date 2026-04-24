import Foundation

enum TraceSessionFileLoader {
    enum DecodedTraceContent {
        case plain(SessionTrace)
        case encrypted(SecureTraceWrapper)
    }
    
    /// Decodes a trace file into either plain session content or encrypted wrapper metadata.
    static func decodeTraceContent(from fileURL: URL) throws -> DecodedTraceContent {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        
        if let trace = try? SessionTraceJSONCodec.decode(from: data) {
            return .plain(trace)
        }
        
        let wrapper: SecureTraceWrapper
        do {
            wrapper = try JSONDecoder().decode(SecureTraceWrapper.self, from: data)
        } catch {
            throw SessionTraceJSONCodecError.decodingFailed(details: "Unsupported trace file format.")
        }
        
        guard wrapper.isEncrypted else {
            throw SessionTraceJSONCodecError.decodingFailed(details: "Unsupported trace file format.")
        }
        
        return .encrypted(wrapper)
    }
    
    static func decryptSession(wrapper: SecureTraceWrapper, password: String) throws -> SessionTrace {
        let decryptedData = try TraceEncryptionService.decryptWrappedTrace(wrapper, password: password)
        return try SessionTraceJSONCodec.decode(from: decryptedData)
    }
    
    /// Flat index for resolving full `NetworkInteraction` payloads in the inspector (not the lightweight snapshot rows).
    static func interactionIndex(from trace: SessionTrace) -> [String: NetworkInteraction] {
        var index: [String: NetworkInteraction] = [:]
        index.reserveCapacity(trace.screens.reduce(0) { $0 + $1.networkInteractions.count })
        for screen in trace.screens {
            for interaction in screen.networkInteractions {
                index[interaction.id] = interaction
            }
        }
        return index
    }
}
