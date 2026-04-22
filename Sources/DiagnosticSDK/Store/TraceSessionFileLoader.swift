import Foundation

enum TraceSessionFileLoader {
    /// Decodes a trace JSON file written by `DiagnosticSessionStore.exportSessionToDisk()`.
    static func decodeSession(from fileURL: URL) throws -> SessionTrace {
        try SessionTraceJSONCodec.decodeFile(at: fileURL)
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
