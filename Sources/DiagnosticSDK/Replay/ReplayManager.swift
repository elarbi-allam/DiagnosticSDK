import Foundation
import Combine

public enum ReplayQueryMatchingMode {
    case strict
    case ignore
}

public enum ReplayError: LocalizedError {
    case emptyTrace

    public var errorDescription: String? {
        switch self {
        case .emptyTrace:
            return "Replay activation failed: trace has no screens."
        }
    }
}

/// Central replay session state shared by history UI, replay configuration tab, and the network interception layer.
@MainActor
public final class ReplayManager: ObservableObject {
    public static let shared = ReplayManager()

    // UI writes these flags; networking core reads them to decide replay behavior.
    @Published public var isReplayActive: Bool = false {
        didSet { publishNetworkingState() }
    }
    @Published public var queryMatchingMode: ReplayQueryMatchingMode = .strict {
        didSet { publishNetworkingState() }
    }
    @Published public var disabledInteractionIDs: Set<String> = [] {
        didSet { publishNetworkingState() }
    }

    /// Active trace loaded from selected history JSON.
    @Published public var activeTrace: SessionTrace? {
        didSet { publishNetworkingState() }
    }

    /// Identifier of the trace file used for the current replay session (history selection / deletion logic).
    @Published public var activeReplayTraceFileId: String?

    private init() {}

    public func activate(with trace: SessionTrace, traceFileId: String? = nil) throws {
        guard !trace.screens.isEmpty else { throw ReplayError.emptyTrace }

        disabledInteractionIDs.removeAll()
        activeTrace = trace
        activeReplayTraceFileId = traceFileId
        isReplayActive = true
    }

    public func deactivate() {
        resetReplayState()
    }

    public func setInteractionEnabled(_ interactionID: String, isEnabled: Bool) {
        if isEnabled {
            disabledInteractionIDs.remove(interactionID)
        } else {
            disabledInteractionIDs.insert(interactionID)
        }
    }

    private func resetReplayState() {
        activeTrace = nil
        activeReplayTraceFileId = nil
        disabledInteractionIDs.removeAll()
        isReplayActive = false
    }

    private func publishNetworkingState() {
        ReplayStateMirror.current.update(
            ReplayNetworkingState(
                isReplayActive: isReplayActive,
                activeTrace: activeTrace,
                disabledInteractionIDs: disabledInteractionIDs,
                queryMatchingMode: queryMatchingMode
            )
        )
    }
}

extension ReplayManager: ReplaySessionStatusProviding {

    var isReplaySessionRunning: Bool {
        Self.isRunning(isReplayActive: isReplayActive, activeTrace: activeTrace)
    }

    var replaySessionRunningPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest($isReplayActive, $activeTrace)
            .map { isReplayActive, activeTrace in
                Self.isRunning(isReplayActive: isReplayActive, activeTrace: activeTrace)
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    nonisolated private static func isRunning(isReplayActive: Bool, activeTrace: SessionTrace?) -> Bool {
        isReplayActive && activeTrace != nil
    }
}
