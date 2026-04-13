import Foundation

/// A high-performance, thread-safe store that manages the diagnostic session in memory.
/// It builds a hierarchical tree of screens and network interactions on the fly
/// to ensure O(1) export performance later, without blocking the host application's main thread.
public final class DiagnosticSessionStore: NetworkStoreProtocol {
    
    /// The shared singleton instance accessed by the interception engine.
    public static let shared = DiagnosticSessionStore()
    
    // MARK: - State
    
    /// The current hierarchical session trace held entirely in RAM.
    private(set) var currentSession: SessionTrace
    
    /// A concurrent dispatch queue acting as a read-write lock to prevent race conditions.
    private let isolationQueue = DispatchQueue(label: "com.diagnosticsdk.sessionstore.isolation", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        self.currentSession = SessionTrace()
    }
    
    // MARK: - NetworkStoreProtocol Implementation
    
    /// Asynchronously stores a captured network event into the hierarchical tree.
    /// - Parameter event: The raw network event intercepted from URLSession.
    public func save(event: NetworkEvent) {
        // Use a barrier block to ensure exclusive write access to the session tree.
        // This guarantees thread safety without blocking reader threads.
        isolationQueue.async(flags: .barrier) { [weak self] in
            self?.processAndAppend(event: event)
        }
    }
    
    // MARK: - Tree Building Logic
    
    /// Processes the raw event and places it into the correct ScreenNode.
    private func processAndAppend(event: NetworkEvent) {
        // Récupération sécurisée du nom de l'écran depuis RequestModel
        let targetScreenName = event.request.screenName ?? "Background"
        let interaction = mapToInteraction(event)
        
        // Check if the user is still interacting with the same screen
        if let currentScreen = currentSession.screens.last, currentScreen.name == targetScreenName {
            currentScreen.networkInteractions.append(interaction)
        } else {
            // User navigated to a new screen: mark the exit time of the previous screen
            currentSession.screens.last?.exitedAt = Date()
            
            // Create and append the new screen node
            let newScreenNode = ScreenNode(name: targetScreenName)
            newScreenNode.networkInteractions.append(interaction)
            currentSession.screens.append(newScreenNode)
        }
    }
    
    // MARK: - Data Mapping
    
    /// Maps a flat NetworkEvent into the hierarchical NetworkInteraction format.
    private func mapToInteraction(_ event: NetworkEvent) -> NetworkInteraction {
        let requestDetails = RequestDetails(
            url: event.request.url,
            method: event.request.method,
            headers: event.request.headers,
            bodyBase64: nil, // Body capturing is omitted here for memory performance
            bodySizeBytes: 0
        )
        
        // Création de l'interaction (l'ID sera généré automatiquement par l'init de NetworkInteraction)
        var interaction = NetworkInteraction(request: requestDetails)
        
        if let response = event.response {
            interaction.response = ResponseDetails(
                status: response.statusCode,
                headers: response.headers,
                bodyBase64: nil,
                bodySizeBytes: response.bodySizeBytes, // Ajout de la taille du body si disponible
                errorDescription: response.errorDescription
            )
            
            // Note: La durée (durationMs) est ignorée pour le moment car `ResponseModel`
            // ne contient pas la propriété `duration`.
            // interaction.durationMs = ...
        }
        
        return interaction
    }
}
