import SwiftUI
import Combine

enum ReplayDisplayMode {
    case timeline
    case grouped
}

struct ReplayInteractionGroup: Identifiable, Equatable {
    let id: String
    let path: String
    let interactions: [ReplayInteractionItem]
}

struct ReplayInteractionItem: Identifiable, Equatable {
    let id: String
    let startedAt: Date
    let method: String
    let hostAndPath: String
    let path: String
    let strictGroupingKey: String
    let ignoreGroupingKey: String
    /// Only used when ReplayManager uses `.strict`; otherwise nil to avoid noisy UI.
    var queryDisplayLine: String? {
        normalizedQuerySorted.isEmpty ? nil : normalizedQuerySorted
    }

    private let normalizedQuerySorted: String

    init(
        id: String,
        startedAt: Date,
        method: String,
        hostAndPath: String,
        path: String,
        strictGroupingKey: String,
        ignoreGroupingKey: String,
        normalizedQuerySorted: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.method = method
        self.hostAndPath = hostAndPath
        self.path = path
        self.strictGroupingKey = strictGroupingKey
        self.ignoreGroupingKey = ignoreGroupingKey
        self.normalizedQuerySorted = normalizedQuerySorted
    }
}
