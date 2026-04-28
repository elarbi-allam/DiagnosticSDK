import Foundation

enum TraceSessionFileLoader {
    enum DecodedTraceContent {
        case plain(SessionTrace)
        case encrypted(SecureTraceWrapper)
    }
    
    /// Decodes a trace file into either plain session content or encrypted wrapper metadata.
    static func decodeTraceContent(from fileURL: URL) throws -> DecodedTraceContent {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw TraceSessionFileLoaderError.fileReadFailed
        }
        
        if let trace = try? SessionTraceJSONCodec.decode(from: data) {
            return .plain(trace)
        }
        
        let wrapper: SecureTraceWrapper
        do {
            wrapper = try JSONDecoder().decode(SecureTraceWrapper.self, from: data)
        } catch {
            throw TraceSessionFileLoaderError.unsupportedFormat
        }
        
        guard wrapper.isEncrypted else {
            throw TraceSessionFileLoaderError.unsupportedFormat
        }
        
        return .encrypted(wrapper)
    }
    
    static func decryptSession(wrapper: SecureTraceWrapper, password: String) throws -> SessionTrace {
        let decryptedData: Data
        do {
            decryptedData = try TraceEncryptionService.decryptWrappedTrace(wrapper, password: password)
        } catch let error as TraceEncryptionServiceError {
            switch error {
            case .invalidSaltEncoding, .invalidEncryptedDataEncoding, .wrapperNotEncrypted:
                throw TraceSessionFileLoaderError.invalidEncryptedFile
            case .emptyPassword, .decryptionFailed, .combinedCiphertextUnavailable:
                throw TraceSessionFileLoaderError.wrongPasswordOrCorruptedFile
            }
        } catch {
            throw TraceSessionFileLoaderError.wrongPasswordOrCorruptedFile
        }
        
        do {
            return try SessionTraceJSONCodec.decode(from: decryptedData)
        } catch {
            throw TraceSessionFileLoaderError.invalidEncryptedFile
        }
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
