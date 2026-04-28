import Foundation
import UIKit

/// A high-performance, thread-safe store that manages the diagnostic session in memory.
public final class DiagnosticSessionStore: NetworkStoreProtocol {
    
    /// The shared singleton instance accessed by the interception engine.
    public static let shared = DiagnosticSessionStore()
    
    // MARK: - State
    
    /// The current hierarchical session trace held entirely in RAM.
    private(set) var currentSession: SessionTrace
    
    /// A concurrent dispatch queue acting as a read-write lock to prevent race conditions.
    private let isolationQueue = DispatchQueue(label: "com.diagnosticsdk.sessionstore.isolation", attributes: .concurrent)
    
    /// Maps a screen visit id to the corresponding screen node index.
    private var screenIndexByVisitId: [Int: Int] = [:]
    private var backgroundObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    private init() {
        self.currentSession = SessionTrace()
        self.setupAutoSave()
    }
    
    deinit {
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
    }
    
    // MARK: - NetworkStoreProtocol Implementation
    
    /// Asynchronously stores a captured network event into the hierarchical tree.
    /// - Parameter event: The raw network event intercepted from URLSession.
    public func save(event: NetworkEvent) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            self?.processAndAppend(event: event)
            NotificationCenter.default.post(name: .diagnosticSessionStoreDidUpdate, object: self)
        }
    }
    
    /// Clears captured screens and interactions while preserving the active session identity.
    public func clearCurrentSessionContent() {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.currentSession.screens.removeAll(keepingCapacity: false)
            self.screenIndexByVisitId.removeAll(keepingCapacity: false)
            NotificationCenter.default.post(name: .diagnosticSessionStoreDidUpdate, object: self)
        }
    }
    
    // MARK: - Tree Building Logic
    
    /// Processes the raw event and places it into the correct ScreenNode.
    private func processAndAppend(event: NetworkEvent) {
        let targetScreenName = event.request.screenName ?? "Background"
        let interaction = mapToInteraction(event)
        let visitId = event.request.screenVisitId
        
        // Attach by screen visit when available to preserve navigation chronology.
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
        
        // Fallback path for events captured without a visit id.
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
        isolationQueue.sync {
            exportedURL = self.writeCurrentSessionToDocuments()
        }
        return exportedURL
    }
    
    /// Performs the standard export to Documents first, then creates an encrypted export in Temporary.
    /// The temporary encrypted file is intended for sharing and should not appear in session history listings.
    /// - Parameter password: User-provided password used to derive the encryption key.
    /// - Returns: The URL of the encrypted temporary file, or `nil` if any step fails.
    @discardableResult
    public func exportSessionSafelyToTemporary(password: String) -> URL? {
        var encryptedURL: URL?
        isolationQueue.sync {
            guard let (_, jsonData) = self.writeCurrentSessionToDocumentsReturningData() else {
                print("❌ [DiagnosticSDK] Safe export aborted: normal export failed.")
                return
            }
            do {
                let wrapped = try TraceEncryptionService.encryptTraceJSON(jsonData, password: password)
                let wrapperData = try JSONEncoder().encode(wrapped)
                let fileName = self.safeExportFileName(for: self.currentSession)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try wrapperData.write(to: tempURL, options: .atomic)
                encryptedURL = tempURL
                print("✅ [DiagnosticSDK] Safe export created in temporary directory: \(tempURL.path)")
            } catch let error as TraceEncryptionServiceError {
                print("❌ [DiagnosticSDK] Safe export failed: \(error.localizedDescription)")
            } catch {
                print("❌ [DiagnosticSDK] Safe export failed: \(error.localizedDescription)")
            }
        }
        return encryptedURL
    }
    
    /// Single encode + write to Documents. Call only on `isolationQueue`.
    private func writeCurrentSessionToDocuments() -> URL? {
        guard let (url, _) = writeCurrentSessionToDocumentsReturningData() else { return nil }
        return url
    }
    
    private func writeCurrentSessionToDocumentsReturningData() -> (url: URL, data: Data)? {
        do {
            let jsonData = try SessionTraceJSONCodec.encode(self.currentSession)
            let fileName = self.exportFileName(for: self.currentSession)
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ [DiagnosticSDK] Failed to export session to disk: missing Documents directory")
                return nil
            }
            let filePath = documentsPath.appendingPathComponent(fileName)
            try jsonData.write(to: filePath, options: .atomic)
            print("✅ [DiagnosticSDK] Session exported successfully to: \(filePath.path)")
            return (filePath, jsonData)
        } catch let error as SessionTraceJSONCodecError {
            print("❌ [DiagnosticSDK] Failed to export session to disk: \(error.localizedDescription)")
        } catch {
            print("❌ [DiagnosticSDK] Failed to export session to disk: \(error.localizedDescription)")
        }
        return nil
    }
    
    /// Listens for the app going into the background to trigger a safety save.
    private func setupAutoSave() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.exportSessionToDisk()
        }
    }
    
    /// Builds a deterministic export file name so one session always overwrites the same JSON file.
    private func exportFileName(for session: SessionTrace) -> String {
        let rawId = session.sessionId.isEmpty
            ? ISO8601DateFormatter().string(from: session.startedAt)
            : session.sessionId
        let normalized = rawId
            .uppercased()
            .filter(\.isHexDigit)
        let shortIdentifier = String(normalized.prefix(7))
        return "Dx_\(shortIdentifier.isEmpty ? "0000000" : shortIdentifier).json"
    }
    
    /// Builds a deterministic temporary file name for encrypted exports.
    private func safeExportFileName(for session: SessionTrace) -> String {
        let regularName = exportFileName(for: session)
        let baseName = regularName.replacingOccurrences(of: ".json", with: "")
        return "\(baseName)_S.json"
    }
}

// MARK: - UI Snapshot (Read-Only)

/// A read-only, value-type snapshot tailored for SwiftUI rendering.
/// This avoids exposing mutable arrays from `ScreenNode` (a reference type) to the UI layer.
public struct DiagnosticSessionSnapshot: Sendable, Equatable {
    public struct Metadata: Sendable, Equatable {
        public let appVersion: String
        public let osVersion: String
        public let deviceModel: String
    }
    
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
    public let metadata: Metadata
    public let screens: [Screen]
    
    public init(sessionId: String, startedAt: Date, metadata: Metadata, screens: [Screen]) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.metadata = metadata
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
                metadata: .init(
                    appVersion: currentSession.metadata.appVersion,
                    osVersion: currentSession.metadata.osVersion,
                    deviceModel: currentSession.metadata.deviceModel
                ),
                screens: screens
            )
        }
    }
}
