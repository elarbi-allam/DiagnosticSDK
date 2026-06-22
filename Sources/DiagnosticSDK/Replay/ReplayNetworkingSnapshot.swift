import Foundation

/// Immutable snapshot of replay-driving state for synchronous networking (e.g. `URLProtocol`),
/// isolated from mutation logic in ``ReplayManager``.
public struct ReplayNetworkingState: Sendable {
    public let isReplayActive: Bool
    public let activeTrace: SessionTrace?
    public let disabledInteractionIDs: Set<String>
    public let queryMatchingMode: ReplayQueryMatchingMode

    public init(isReplayActive: Bool, activeTrace: SessionTrace?, disabledInteractionIDs: Set<String>, queryMatchingMode: ReplayQueryMatchingMode) {
        self.isReplayActive = isReplayActive
        self.activeTrace = activeTrace
        self.disabledInteractionIDs = disabledInteractionIDs
        self.queryMatchingMode = queryMatchingMode
    }
}

/// Bridges MainActor-isolated ``ReplayManager`` into synchronous URL interception; ``ReplayManager`` stays state-only.
public enum ReplayNetworking {
    /// Uses the MainActor executor synchronously because URLProtocol cannot await actor isolation.
    public static func captureSynchronouslyForURLIntercept() -> ReplayNetworkingState {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                let manager = ReplayManager.shared
                return ReplayNetworkingState(
                    isReplayActive: manager.isReplayActive,
                    activeTrace: manager.activeTrace,
                    disabledInteractionIDs: manager.disabledInteractionIDs,
                    queryMatchingMode: manager.queryMatchingMode
                )
            }
        }

        var state: ReplayNetworkingState!
        DispatchQueue.main.sync {
            state = MainActor.assumeIsolated {
                let manager = ReplayManager.shared
                return ReplayNetworkingState(
                    isReplayActive: manager.isReplayActive,
                    activeTrace: manager.activeTrace,
                    disabledInteractionIDs: manager.disabledInteractionIDs,
                    queryMatchingMode: manager.queryMatchingMode
                )
            }
        }
        return state
    }
}
