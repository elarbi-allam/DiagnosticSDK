import SwiftUI
import Combine

@MainActor
final class ReplayConfigurationViewModel: ObservableObject {
    @Published private(set) var isReplayActive: Bool
    @Published private(set) var queryMatchingMode: ReplayQueryMatchingMode
    @Published private(set) var timelineInteractions: [ReplayInteractionItem] = []
    @Published private(set) var groups: [ReplayInteractionGroup] = []
    @Published var selectedInteractionDetails: NetworkInteraction?

    var isStrictMatching: Bool {
        queryMatchingMode == .strict
    }

    var matchingModeLabel: String {
        switch queryMatchingMode {
        case .strict: return "Strict (path + query)"
        case .ignore: return "Ignore query"
        }
    }

    private let replayManager: ReplayManager
    private var cancellables = Set<AnyCancellable>()

    init(replayManager: ReplayManager = .shared) {
        self.replayManager = replayManager
        self.isReplayActive = replayManager.isReplayActive
        self.queryMatchingMode = replayManager.queryMatchingMode

        bindState()
        reloadGroups()
    }

    func setInteractionEnabled(_ interactionID: String, isEnabled: Bool) {
        replayManager.setInteractionEnabled(interactionID, isEnabled: isEnabled)
    }

    func selectInteractionForDetails(_ interaction: NetworkInteraction) {
        selectedInteractionDetails = interaction
    }

    func toggleReplayState(isOn: Bool) {
        if isOn {
            return
        }
        replayManager.deactivate()
    }

    private func bindState() {
        replayManager.$isReplayActive
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                self?.isReplayActive = isActive
            }
            .store(in: &cancellables)

        replayManager.$queryMatchingMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.queryMatchingMode = mode
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            replayManager.$activeTrace,
            replayManager.$queryMatchingMode
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _ in
            self?.reloadGroups()
        }
        .store(in: &cancellables)
    }

    private func reloadGroups() {
        guard let trace = replayManager.activeTrace else {
            timelineInteractions = []
            groups = []
            return
        }

        let mode = replayManager.queryMatchingMode
        let interactions = trace.screens
            .flatMap(\.networkInteractions)
            .sorted { $0.startedAt < $1.startedAt }
            .map { makeReplayInteractionItem(from: $0) }
        timelineInteractions = interactions

        let grouped = Dictionary(grouping: interactions) { item -> String in
            switch mode {
            case .strict:
                return item.strictGroupingKey
            case .ignore:
                return item.ignoreGroupingKey
            }
        }

        groups = grouped
            .map { groupingKey, groupedInteractions in
                ReplayInteractionGroup(
                    id: groupingKey,
                    path: groupedInteractions.first?.path ?? "/",
                    interactions: groupedInteractions.sorted { $0.startedAt < $1.startedAt }
                )
            }
            .sorted { leftGroup, rightGroup in
                let leftGroupFirstInteractionDate = leftGroup.interactions.first?.startedAt ?? .distantPast
                let rightGroupFirstInteractionDate = rightGroup.interactions.first?.startedAt ?? .distantPast
                return leftGroupFirstInteractionDate < rightGroupFirstInteractionDate
            }
    }

    private func makeReplayInteractionItem(from interaction: NetworkInteraction) -> ReplayInteractionItem {
        let requestURL = URL(string: interaction.request.url)
        let urlComponents = requestURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let host = requestURL?.host ?? ""
        let path = normalizedPath(from: urlComponents?.path ?? requestURL?.path ?? "/")
        let method = normalizedMethod(from: interaction.request.method)
        let normalizedAndSortedQuery = normalizedQueryItems(from: urlComponents?.queryItems)

        let strictGroupingKey = "\(method)|\(path)|\(normalizedAndSortedQuery)"
        let ignoreGroupingKey = "\(method)|\(path)"

        return ReplayInteractionItem(
            id: interaction.id,
            startedAt: interaction.startedAt,
            method: method,
            hostAndPath: host.isEmpty ? path : "\(host)\(path)",
            path: path,
            strictGroupingKey: strictGroupingKey,
            ignoreGroupingKey: ignoreGroupingKey,
            normalizedQuerySorted: normalizedAndSortedQuery,
            originalInteraction: interaction
        )
    }

    private func normalizedMethod(from method: String?) -> String {
        (method ?? "GET")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizedPath(from path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "/" : trimmed
    }

    private func normalizedQueryItems(from queryItems: [URLQueryItem]?) -> String {
        guard let queryItems, !queryItems.isEmpty else { return "" }

        let normalized = queryItems
            .map { "\($0.name)=\($0.value ?? "")" }
            .sorted()

        return normalized.joined(separator: "&")
    }
}
