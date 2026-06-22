import Foundation

public final class ReplayMatchEngine {
    private let cacheLock = NSLock()
    private var cachedTraceKey: TraceCacheKey?
    private var cachedPreparedInteractions: [PreparedInteraction] = []

    public init() {}

    public func findMatch(
        for liveRequest: URLRequest,
        in trace: SessionTrace,
        disabledInteractionIDs: Set<String>,
        queryMatchingMode: ReplayQueryMatchingMode
    ) -> NetworkInteraction? {
        guard
            let liveURL = liveRequest.url,
            let liveComponents = URLComponents(url: liveURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let liveMethod = normalizedMethod(from: liveRequest.httpMethod)
        let livePath = normalizedPath(from: liveComponents.path)
        let liveQueryItems = normalizedQueryItems(from: liveComponents.queryItems)
        let preparedInteractions = preparedInteractions(for: trace)

        for prepared in preparedInteractions {
            if disabledInteractionIDs.contains(prepared.id) {
                continue
            }

            guard liveMethod == prepared.method, livePath == prepared.path else {
                continue
            }

            if matchesQueries(
                liveQueryItems: liveQueryItems,
                mockQueryItems: prepared.queryItems,
                mode: queryMatchingMode
            ) {
                return prepared.interaction
            }
        }

        return nil
    }

    private func preparedInteractions(for trace: SessionTrace) -> [PreparedInteraction] {
        let cacheKey = TraceCacheKey(sessionId: trace.sessionId, screenCount: trace.screens.count, interactionCount: trace.screens.reduce(0) { $0 + $1.networkInteractions.count })

        cacheLock.lock()
        defer { cacheLock.unlock() }

        if cachedTraceKey == cacheKey {
            return cachedPreparedInteractions
        }

        let prepared = trace.screens
            .flatMap(\.networkInteractions)
            .compactMap { interaction -> PreparedInteraction? in
                guard
                    let components = URLComponents(string: interaction.request.url),
                    storedResponseAllowsJSONMocking(interaction)
                else {
                    return nil
                }

                return PreparedInteraction(
                    interaction: interaction,
                    method: normalizedMethod(from: interaction.request.method),
                    path: normalizedPath(from: components.path),
                    queryItems: normalizedQueryItems(from: components.queryItems)
                )
            }

        cachedTraceKey = cacheKey
        cachedPreparedInteractions = prepared
        return prepared
    }

    private func normalizedMethod(from method: String?) -> String {
        (method ?? "GET")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func normalizedPath(from path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.isEmpty {
            return "/"
        }
        return trimmedPath
    }

    private func normalizedQueryItems(from queryItems: [URLQueryItem]?) -> [QueryToken: Int] {
        var histogram: [QueryToken: Int] = [:]

        for item in queryItems ?? [] {
            let token = QueryToken(name: item.name, value: item.value)
            histogram[token, default: 0] += 1
        }

        return histogram
    }

    private func matchesQueries(
        liveQueryItems: [QueryToken: Int],
        mockQueryItems: [QueryToken: Int],
        mode: ReplayQueryMatchingMode
    ) -> Bool {
        switch mode {
        case .strict:
            return liveQueryItems == mockQueryItems
        case .ignore:
            return true
        }
    }

    private func storedResponseAllowsJSONMocking(_ interaction: NetworkInteraction) -> Bool {
        guard let headers = interaction.response?.headers, !headers.isEmpty else {
            return false
        }

        guard let rawContentType = headers.first(where: { key, _ in
            key.caseInsensitiveCompare("Content-Type") == .orderedSame
        })?.value else {
            return false
        }

        let primaryMediaType = rawContentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if primaryMediaType.isEmpty {
            return false
        }

        return primaryMediaType.contains("json")
    }
}

private struct PreparedInteraction {
    let interaction: NetworkInteraction
    let id: String
    let method: String
    let path: String
    let queryItems: [QueryToken: Int]

    init(interaction: NetworkInteraction, method: String, path: String, queryItems: [QueryToken: Int]) {
        self.interaction = interaction
        self.id = interaction.id
        self.method = method
        self.path = path
        self.queryItems = queryItems
    }
}

private struct TraceCacheKey: Equatable {
    let sessionId: String
    let screenCount: Int
    let interactionCount: Int
}

private struct QueryToken: Hashable {
    let name: String
    let value: String?
}
