import Foundation
import UIKit

/// A high-performance, thread-safe store that manages the diagnostic session in memory.
/// It builds a hierarchical tree of screens and network interactions.
public final class DiagnosticSessionStore: NetworkStoreProtocol {
    
    /// The shared singleton instance accessed by the interception engine.
    public static let shared = DiagnosticSessionStore()
    
    // MARK: - State
    
    /// The current hierarchical session trace held entirely in RAM.
    private(set) var currentSession: SessionTrace
    
    /// A concurrent dispatch queue acting as a read-write lock to prevent race conditions.
    private let isolationQueue = DispatchQueue(label: "com.diagnosticsdk.sessionstore.isolation", attributes: .concurrent)
    
    /// Maps a screen visit id to the corresponding screen node index.
    /// This preserves navigation chronology even when the same screen name appears multiple times.
    private var screenIndexByVisitId: [Int: Int] = [:]
    
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
            NotificationCenter.default.post(name: .diagnosticSessionStoreDidUpdate, object: self)
        }
    }
    
    // MARK: - Tree Building Logic
    
    /// Processes the raw event and places it into the correct ScreenNode.
    private func processAndAppend(event: NetworkEvent) {
        let targetScreenName = event.request.screenName ?? "Background"
        let interaction = mapToInteraction(event)
        let visitId = event.request.screenVisitId
        
        // Preferred path: attach by unique visit id captured when the request started.
        // This keeps Home -> Detail -> Home as distinct blocks and still handles async responses correctly.
        if let visitId {
            if let idx = screenIndexByVisitId[visitId], idx < currentSession.screens.count {
                currentSession.screens[idx].networkInteractions.append(interaction)
                return
            }
            
            let newScreenNode = ScreenNode(name: targetScreenName)
            newScreenNode.networkInteractions.append(interaction)
            currentSession.screens.append(newScreenNode)
            screenIndexByVisitId[visitId] = currentSession.screens.count - 1
            return
        }
        
        // Fallback for older events: only merge with the currently open tail screen.
        // If navigation moved in-between, create a new screen node even with the same name.
        if let idx = currentSession.screens.indices.last,
           currentSession.screens[idx].name == targetScreenName {
            currentSession.screens[idx].networkInteractions.append(interaction)
            return
        }
        
        let newScreenNode = ScreenNode(name: targetScreenName)
        newScreenNode.networkInteractions.append(interaction)
        currentSession.screens.append(newScreenNode)
    }
    
    // MARK: - Data Mapping
    
    /// Maps a flat NetworkEvent into the hierarchical NetworkInteraction format.
    private func mapToInteraction(_ event: NetworkEvent) -> NetworkInteraction {
        let requestDetails = RequestDetails(
            url: event.request.url,
            method: event.request.method,
            headers: event.request.headers,
            bodyBase64: event.request.body,
            bodySizeBytes: event.request.body?.utf8.count ?? 0
        )
        
        var interaction = NetworkInteraction(
            request: requestDetails,
            screenName: event.request.screenName
        )
        
        if let response = event.response {
            interaction.response = ResponseDetails(
                status: response.statusCode,
                headers: response.headers,
                bodyBase64: response.bodyBase64,
                bodySizeBytes: response.bodySizeBytes,
                errorDescription: response.errorDescription
            )
            
            interaction.durationMs = event.durationMs
        }
        
        return interaction
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let diagnosticSessionStoreDidUpdate = Notification.Name("com.diagnosticsdk.sessionstore.didUpdate")
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

// MARK: - UI Snapshot (Read-Only)

/// A read-only, value-type snapshot tailored for SwiftUI rendering.
/// This avoids exposing mutable arrays from `ScreenNode` (a reference type) to the UI layer.
public struct DiagnosticSessionSnapshot: Sendable, Equatable {
    public struct Screen: Identifiable, Sendable, Equatable {
        public let id: String
        public let name: String
        public let enteredAt: Date
        public let exitedAt: Date?
        public let interactions: [Interaction]
    }
    
    public struct Interaction: Identifiable, Sendable, Equatable {
        public let id: String
        public let startedAt: Date
        public let durationMs: Int?
        public let method: String
        public let url: String
        public let status: Int?
    }
    
    public let sessionId: String
    public let startedAt: Date
    public let screens: [Screen]
    
    public init(sessionId: String, startedAt: Date, screens: [Screen]) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.screens = screens
    }
}

extension DiagnosticSessionStore {
    
    /// Thread-safe lookup for a full interaction payload by id.
    /// This is used by detail screens where lightweight snapshots are insufficient.
    public func getInteraction(byId id: String) -> NetworkInteraction? {
        isolationQueue.sync {
            for screen in currentSession.screens {
                if let interaction = screen.networkInteractions.first(where: { $0.id == id }) {
                    return interaction
                }
            }
            return nil
        }
    }
    
    /// Produces a thread-safe snapshot for UI rendering.
    /// - Important: This executes a synchronous read on the store's isolation queue.
    public func makeSnapshot() -> DiagnosticSessionSnapshot {
        isolationQueue.sync {
            let screens: [DiagnosticSessionSnapshot.Screen] = currentSession.screens.map { screen in
                let interactions: [DiagnosticSessionSnapshot.Interaction] = screen.networkInteractions.map { interaction in
                    DiagnosticSessionSnapshot.Interaction(
                        id: interaction.id,
                        startedAt: interaction.startedAt,
                        durationMs: interaction.durationMs,
                        method: interaction.request.method,
                        url: interaction.request.url,
                        status: interaction.response?.status
                    )
                }
                
                return DiagnosticSessionSnapshot.Screen(
                    id: screen.id,
                    name: screen.name,
                    enteredAt: screen.enteredAt,
                    exitedAt: screen.exitedAt,
                    interactions: interactions
                )
            }
            
            return DiagnosticSessionSnapshot(
                sessionId: currentSession.sessionId,
                startedAt: currentSession.startedAt,
                screens: screens
            )
        }
    }
}
