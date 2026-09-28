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
    private var mockedInteractionIds: Set<String> = []
    private var interactionLocationsById: [String: InteractionLocation] = [:]
    private var isUpdateNotificationScheduled = false
    private var backgroundObserver: NSObjectProtocol?
    
    private static let updateNotificationCoalescingInterval: TimeInterval = 0.15
    private static let interruptedCaptureErrorDescription = "Capture stopped before the response was received"
    
    private struct InteractionLocation {
        let screenIndex: Int
        let interactionIndex: Int
    }
    
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
            guard let self else { return }
            self.storeCompletedInteraction(from: event)
            self.scheduleUpdateNotification()
        }
    }
    
    /// Clears captured screens and interactions while preserving the active session identity.
    public func clearCurrentSessionContent() {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.currentSession.screens.removeAll(keepingCapacity: false)
            self.screenIndexByVisitId.removeAll(keepingCapacity: false)
            self.mockedInteractionIds.removeAll(keepingCapacity: false)
            self.interactionLocationsById.removeAll(keepingCapacity: false)
            self.scheduleUpdateNotification()
        }
    }
    
    func beginInteraction(_ interactionStart: NetworkInteractionStart) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self, self.interactionLocationsById[interactionStart.id] == nil else { return }
            let requestModel = NetworkEventBuilder.makeRequestModel(
                from: interactionStart.request,
                screenName: interactionStart.screenName,
                screenVisitId: interactionStart.screenVisitId
            )
            let pendingInteraction = NetworkInteraction(
                id: interactionStart.id,
                request: self.makeRequestDetails(from: requestModel),
                screenName: interactionStart.screenName,
                startedAt: interactionStart.startedAt
            )
            self.appendInteraction(
                pendingInteraction,
                screenName: interactionStart.screenName,
                visitId: interactionStart.screenVisitId
            )
            self.scheduleUpdateNotification()
        }
    }
    
    func updateTiming(_ timing: NetworkTiming, forInteractionId interactionId: String) {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self, let location = self.interactionLocationsById[interactionId] else { return }
            let screen = self.currentSession.screens[location.screenIndex]
            screen.networkInteractions[location.interactionIndex].timing = timing
            screen.networkInteractions[location.interactionIndex].durationMs = timing.preferredDurationMs
            self.scheduleUpdateNotification()
        }
    }
    
    func interruptPendingInteractions() {
        isolationQueue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var hasInterruptedInteraction = false
            for screen in self.currentSession.screens {
                for interactionIndex in screen.networkInteractions.indices where screen.networkInteractions[interactionIndex].response == nil {
                    screen.networkInteractions[interactionIndex].response = Self.makeInterruptedResponse()
                    hasInterruptedInteraction = true
                }
            }
            if hasInterruptedInteraction {
                self.scheduleUpdateNotification()
            }
        }
    }
    
    private static func makeInterruptedResponse() -> ResponseDetails {
        ResponseDetails(
            status: 0,
            headers: nil,
            bodyBase64: nil,
            bodySizeBytes: 0,
            errorDescription: interruptedCaptureErrorDescription
        )
    }
    
    private func scheduleUpdateNotification() {
        guard !isUpdateNotificationScheduled else { return }
        isUpdateNotificationScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.updateNotificationCoalescingInterval) { [weak self] in
            self?.isolationQueue.async(flags: .barrier) {
                guard let self else { return }
                self.isUpdateNotificationScheduled = false
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .diagnosticSessionStoreDidUpdate, object: self)
                }
            }
        }
    }
    
    // MARK: - Tree Building Logic
    
    private func storeCompletedInteraction(from event: NetworkEvent) {
        let completedInteraction = mapToInteraction(event)
        if event.isMocked {
            mockedInteractionIds.insert(completedInteraction.id)
        }
        if let location = interactionLocationsById[completedInteraction.id] {
            currentSession.screens[location.screenIndex].networkInteractions[location.interactionIndex] = completedInteraction
            return
        }
        appendInteraction(completedInteraction, screenName: event.request.screenName, visitId: event.request.screenVisitId)
    }
    
    private func appendInteraction(_ interaction: NetworkInteraction, screenName: String?, visitId: Int?) {
        let screenIndex = screenIndexForAppending(screenName: screenName ?? "Background", visitId: visitId)
        let screen = currentSession.screens[screenIndex]
        screen.networkInteractions.append(interaction)
        interactionLocationsById[interaction.id] = InteractionLocation(
            screenIndex: screenIndex,
            interactionIndex: screen.networkInteractions.count - 1
        )
    }
    
    private func screenIndexForAppending(screenName: String, visitId: Int?) -> Int {
        if let visitId {
            if let screenIndex = screenIndexByVisitId[visitId], screenIndex < currentSession.screens.count {
                return screenIndex
            }
            let screenIndex = appendScreen(named: screenName)
            screenIndexByVisitId[visitId] = screenIndex
            return screenIndex
        }
        if let lastScreenIndex = currentSession.screens.indices.last,
           currentSession.screens[lastScreenIndex].name == screenName {
            return lastScreenIndex
        }
        return appendScreen(named: screenName)
    }
    
    private func appendScreen(named screenName: String) -> Int {
        currentSession.screens.append(ScreenNode(name: screenName))
        return currentSession.screens.count - 1
    }
    
    // MARK: - Data Mapping
    
    /// Maps a flat NetworkEvent into the hierarchical NetworkInteraction format.
    private func mapToInteraction(_ event: NetworkEvent) -> NetworkInteraction {
        var interaction = NetworkInteraction(
            id: event.captureId ?? UUID().uuidString,
            request: makeRequestDetails(from: event.request),
            screenName: event.request.screenName,
            startedAt: event.startedAt ?? event.timestamp
        )
        interaction.timing = event.timing
        
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
    
    private func makeRequestDetails(from request: RequestModel) -> RequestDetails {
        RequestDetails(
            url: request.url,
            method: request.method,
            headers: request.headers,
            bodyBase64: request.body,
            bodySizeBytes: request.body?.utf8.count ?? 0
        )
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
        public let deviceName: String
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
        public let isMocked: Bool
        public let isPending: Bool
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
            guard let location = interactionLocationsById[id] else { return nil }
            return currentSession.screens[location.screenIndex].networkInteractions[location.interactionIndex]
        }
    }
    
    /// Produces a thread-safe snapshot for UI rendering.
    /// - Important: This executes a synchronous read on the store's isolation queue.
    public func makeSnapshot() -> DiagnosticSessionSnapshot {
        isolationQueue.sync {
            let screens: [DiagnosticSessionSnapshot.Screen] = currentSession.screens.map { screen in
                let interactions = screen.networkInteractions.map { interaction in
                    DiagnosticSessionSnapshot.Interaction(
                        interaction: interaction,
                        isMocked: mockedInteractionIds.contains(interaction.id)
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
                metadata: DiagnosticSessionSnapshot.Metadata(traceMetadata: currentSession.metadata),
                screens: screens
            )
        }
    }
}
