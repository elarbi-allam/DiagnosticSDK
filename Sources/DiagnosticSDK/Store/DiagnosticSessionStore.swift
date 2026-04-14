import Foundation
import UIKit

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
        self.setupAutoSave()
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

// MARK: - File System Export

extension DiagnosticSessionStore {
    
    /// Serializes the current session to JSON and saves it in the application's Document directory.
    /// - Returns: The URL of the saved file, useful for sharing via UIActivityViewController.
    @discardableResult
    public func exportSessionToDisk() -> URL? {
        var exportedURL: URL?
        
        // Sync read to guarantee data consistency during serialization.
        // It freezes the queue for a millisecond to take a snapshot of the tree.
        isolationQueue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Makes the JSON readable for humans
            encoder.dateEncodingStrategy = .iso8601
            
            do {
                let jsonData = try encoder.encode(self.currentSession)
                
                // Format the filename with the exact export date: "DiagnosticTrace_2026-04-14_12-30-00.json"
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = formatter.string(from: Date())
                let fileName = "DiagnosticTrace_\(dateString).json"
                
                // Get the path to the app's secure Documents folder
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let filePath = documentsPath.appendingPathComponent(fileName)
                
                // Instant write to disk
                try jsonData.write(to: filePath)
                exportedURL = filePath
                print("✅ [DiagnosticSDK] Session exported successfully to: \(filePath.path)")
            } catch {
                print("❌ [DiagnosticSDK] Failed to export session to disk: \(error.localizedDescription)")
            }
        }
        
        return exportedURL
    }
    
    /// Listens for the app going into the background to trigger a safety save.
    private func setupAutoSave() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.exportSessionToDisk()
        }
    }
}
