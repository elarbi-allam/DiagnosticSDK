import Foundation

@MainActor
protocol SessionReplayCoordinating {
    func activateReplay(for file: DiagnosticTraceFileInfo, queryMode: ReplayQueryMatchingMode) async throws
    func stopReplay()
    func isReplaySelected(_ file: DiagnosticTraceFileInfo) -> Bool
    func deactivateReplayIfNeeded(for filesToDelete: [DiagnosticTraceFileInfo])
}

@MainActor
struct SessionReplayCoordinator: SessionReplayCoordinating {
    private let replayManager: ReplayManager

    init(replayManager: ReplayManager = .shared) {
        self.replayManager = replayManager
    }

    func activateReplay(for file: DiagnosticTraceFileInfo, queryMode: ReplayQueryMatchingMode) async throws {
        let decodedURL = file.url
        let traceFileID = file.id

        try Task.checkCancellation()

        let trace = try await Task(priority: .userInitiated) {
            try SessionTraceJSONCodec.decodeFile(at: decodedURL)
        }.value

        try Task.checkCancellation()

        replayManager.queryMatchingMode = queryMode
        try replayManager.activate(with: trace, traceFileId: traceFileID)
    }

    func stopReplay() {
        replayManager.deactivate()
    }

    func isReplaySelected(_ file: DiagnosticTraceFileInfo) -> Bool {
        replayManager.activeReplayTraceFileId == file.id && replayManager.isReplayActive
    }

    func deactivateReplayIfNeeded(for filesToDelete: [DiagnosticTraceFileInfo]) {
        guard replayManager.isReplayActive else { return }
        guard let activeReplayTraceFileId = replayManager.activeReplayTraceFileId else { return }
        let deletingActiveReplayFile = filesToDelete.contains { $0.id == activeReplayTraceFileId }
        guard deletingActiveReplayFile else { return }
        replayManager.deactivate()
    }
}
