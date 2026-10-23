import Foundation

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

    static let inactive = ReplayNetworkingState(
        isReplayActive: false,
        activeTrace: nil,
        disabledInteractionIDs: [],
        queryMatchingMode: .strict
    )
}

enum ReplayStateMirror {
    static let current = LockedValue(ReplayNetworkingState.inactive)
}
