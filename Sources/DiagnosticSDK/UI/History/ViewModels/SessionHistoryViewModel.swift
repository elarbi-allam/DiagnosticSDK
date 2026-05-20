import Foundation
import Combine

struct SessionHistoryShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum SessionHistorySourceFilter: Hashable {
    case all
    case thisPhone
    case imported
    
    var title: String {
        switch self {
        case .all: return "All"
        case .thisPhone: return "This Phone"
        case .imported: return "Imported"
        }
    }
}

@MainActor
final class SessionHistoryViewModel: ObservableObject {
    @Published private(set) var files: [DiagnosticTraceFileInfo] = []
    @Published private(set) var isScanning = false
    @Published var importErrorMessage: String?
    @Published var deleteErrorMessage: String?
    @Published var exportErrorMessage: String?
    @Published var shareItem: SessionHistoryShareItem?
    @Published var sourceFilter: SessionHistorySourceFilter = .all
    @Published var replayErrorMessage: String?
    @Published private(set) var isActivatingReplay = false

    private var replayActivationTask: Task<Void, Never>?
    private var replayActivationGeneration: UInt64 = 0
    private let fileManager: SessionHistoryFileManaging
    private let replayCoordinator: SessionReplayCoordinating

    init(
        fileManager: SessionHistoryFileManaging,
        replayCoordinator: SessionReplayCoordinating? = nil
    ) {
        self.fileManager = fileManager
        self.replayCoordinator = replayCoordinator ?? SessionReplayCoordinator()
    }
    
    var visibleFiles: [DiagnosticTraceFileInfo] {
        switch sourceFilter {
        case .all:
            return files
        case .thisPhone:
            return files.filter { $0.source == .session }
        case .imported:
            return files.filter { $0.source == .imported }
        }
    }
    
    func refresh() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fileManager.listTraceFiles() }
            DispatchQueue.main.async {
                self.isScanning = false
                switch result {
                case .success(let list):
                    self.files = list
                case .failure:
                    self.files = []
                }
            }
        }
    }
    
    func delete(at offsets: IndexSet) {
        let filesToDelete = offsets.compactMap { index -> DiagnosticTraceFileInfo? in
            guard visibleFiles.indices.contains(index) else { return nil }
            return visibleFiles[index]
        }
        delete(filesToDelete)
    }
    
    func delete(file: DiagnosticTraceFileInfo) {
        delete([file])
    }
    
    func clearAllFiles() {
        let filesToDelete = files
        delete(filesToDelete)
    }
    
    func importExternalTrace(from sourceURL: URL) {
        let startedAccess = sourceURL.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fileManager.copyImportedTrace(from: sourceURL) }
            DispatchQueue.main.async {
                if startedAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
                switch result {
                case .success(let importedURL):
                    print("✅ [DiagnosticSDK] Imported trace JSON: \(importedURL.lastPathComponent)")
                    self.importErrorMessage = nil
                    self.refresh()
                case .failure(let error):
                    self.importErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func selectFilter(_ filter: SessionHistorySourceFilter) {
        sourceFilter = filter
    }

    func activateReplay(for file: DiagnosticTraceFileInfo, queryMode: ReplayQueryMatchingMode) {
        replayActivationTask?.cancel()

        replayActivationGeneration += 1
        let generation = replayActivationGeneration

        replayErrorMessage = nil
        isActivatingReplay = true

        replayActivationTask = Task { [weak self] in
            guard let self else { return }

            defer {
                if generation == self.replayActivationGeneration {
                    self.isActivatingReplay = false
                }
            }

            guard !Task.isCancelled else { return }

            do {
                try Task.checkCancellation()
                try await self.replayCoordinator.activateReplay(for: file, queryMode: queryMode)
                self.replayErrorMessage = nil
            } catch {
                guard !(error is CancellationError) else { return }
                self.replayErrorMessage = error.localizedDescription
            }
        }
    }

    func stopReplay() {
        replayCoordinator.stopReplay()
    }

    func isReplaySelected(_ file: DiagnosticTraceFileInfo) -> Bool {
        replayCoordinator.isReplaySelected(file)
    }

    func prepareShare(for file: DiagnosticTraceFileInfo) {
        shareItem = SessionHistoryShareItem(url: file.url)
    }
    
    func prepareSafeShare(for file: DiagnosticTraceFileInfo, password: String) {
        exportErrorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = Result { try self.fileManager.createSafeExportTemporaryFile(from: file.url, password: password) }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let safeURL):
                    self.exportErrorMessage = nil
                    self.shareItem = SessionHistoryShareItem(url: safeURL)
                case .failure(let error):
                    self.exportErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func delete(_ filesToDelete: [DiagnosticTraceFileInfo]) {
        guard !filesToDelete.isEmpty else { return }
        replayCoordinator.deactivateReplayIfNeeded(for: filesToDelete)

        let idsToDelete = Set(filesToDelete.map(\.id))
        files.removeAll { idsToDelete.contains($0.id) }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let firstErrorMessage = self.executeDelete(filesToDelete)
            DispatchQueue.main.async {
                self.deleteErrorMessage = firstErrorMessage
                self.refresh()
            }
        }
    }

    private func executeDelete(_ filesToDelete: [DiagnosticTraceFileInfo]) -> String? {
        var firstErrorMessage: String?

        for file in filesToDelete {
            do {
                print("[DiagnosticSDK] Delete requested for: \(file.fileName) at \(file.url.path)")
                let report = try fileManager.deleteTraceFile(at: file.url)
                if report.deleted {
                    print("✅ [DiagnosticSDK] Deleted trace JSON: \(file.fileName)")
                    print("[DiagnosticSDK] \(report.debugMessage)")
                } else if firstErrorMessage == nil {
                    print("[DiagnosticSDK] Delete skipped (file not found): \(file.fileName)")
                    print("[DiagnosticSDK] \(report.debugMessage)")
                    firstErrorMessage = "File not found on disk: \(file.fileName)"
                }
            } catch {
                print("❌ [DiagnosticSDK] Failed to delete trace JSON \(file.fileName): \(error.localizedDescription)")
                if firstErrorMessage == nil {
                    firstErrorMessage = error.localizedDescription
                }
            }
        }

        return firstErrorMessage
    }
}
