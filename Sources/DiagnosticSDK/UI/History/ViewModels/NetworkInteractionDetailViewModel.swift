import Foundation
import Combine

struct NetworkInteractionDetailContent {
    let requestHeaders: FormattedHTTPHeaders
    let requestBody: FormattedHTTPBody
    let requestTokens: [DecodedTokenItem]
    let responseHeaders: FormattedHTTPHeaders
    let responseBody: FormattedHTTPBody
    let responseTokens: [DecodedTokenItem]
    let responseError: FormattedHTTPBody
    let timingRows: [NetworkTimingRow]

    init(interaction: NetworkInteraction) {
        let request = interaction.request
        let response = interaction.response
        requestHeaders = HTTPPayloadFormatter.format(headers: request.headers)
        requestBody = HTTPPayloadFormatter.format(rawBody: request.bodyBase64)
        requestTokens = DecodedTokenExtractor.extract(
            headers: request.headers,
            bodyRawValue: request.bodyBase64,
            sourcePrefix: "Request"
        )
        responseHeaders = HTTPPayloadFormatter.format(headers: response?.headers)
        responseBody = HTTPPayloadFormatter.format(rawBody: response?.bodyBase64)
        responseTokens = response.map {
            DecodedTokenExtractor.extract(headers: $0.headers, bodyRawValue: $0.bodyBase64, sourcePrefix: "Response")
        } ?? []
        responseError = HTTPPayloadFormatter.format(text: response?.errorDescription)
        timingRows = NetworkTimingRowsBuilder.makeRows(for: interaction.timing)
    }
}

@MainActor
final class NetworkInteractionDetailViewModel: ObservableObject {
    private static let synchronousFormattingByteLimit = 256 * 1024

    @Published private(set) var interaction: NetworkInteraction?
    @Published private(set) var content: NetworkInteractionDetailContent?

    private let interactionId: String
    private let store: DiagnosticSessionStore?
    private let captureSource: TraceCaptureSource
    private var storeUpdateCancellable: AnyCancellable?
    private var contentFormattingTask: Task<Void, Never>?
    private var hasStarted = false

    init(interactionId: String, store: DiagnosticSessionStore) {
        self.interactionId = interactionId
        self.store = store
        self.captureSource = .liveSession
    }

    init(archivedInteraction: NetworkInteraction) {
        self.interactionId = archivedInteraction.id
        self.store = nil
        self.captureSource = .archivedTrace
        self.interaction = archivedInteraction
    }

    func responseAvailability(of interaction: NetworkInteraction) -> ResponseAvailability {
        ResponseAvailability(response: interaction.response, captureSource: captureSource)
    }

    func displayedStatus(of interaction: NetworkInteraction) -> String {
        guard responseAvailability(of: interaction) == .received, let response = interaction.response else {
            return TraceValuePlaceholder.unavailable
        }
        return "\(response.status)"
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        if let interaction {
            formatContent(for: interaction)
        } else {
            refreshFromStore()
        }
        observeStoreUntilResponseIsCaptured()
    }

    private func observeStoreUntilResponseIsCaptured() {
        guard store != nil, interaction?.response == nil else { return }
        storeUpdateCancellable = NotificationCenter.default
            .publisher(for: .diagnosticSessionStoreDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromStore()
            }
    }

    private func refreshFromStore() {
        guard let store, let latestInteraction = store.getInteraction(byId: interactionId) else { return }
        guard interaction.map(NetworkInteractionCaptureSignature.init) != NetworkInteractionCaptureSignature(latestInteraction) else { return }
        interaction = latestInteraction
        formatContent(for: latestInteraction)
        if latestInteraction.response != nil {
            storeUpdateCancellable = nil
        }
    }

    private func formatContent(for interaction: NetworkInteraction) {
        contentFormattingTask?.cancel()
        if Self.capturedBodyByteCount(of: interaction) <= Self.synchronousFormattingByteLimit {
            content = NetworkInteractionDetailContent(interaction: interaction)
            return
        }
        content = nil
        contentFormattingTask = Task { [weak self] in
            let formattedContent = await Task.detached(priority: .userInitiated) {
                NetworkInteractionDetailContent(interaction: interaction)
            }.value
            guard !Task.isCancelled else { return }
            self?.content = formattedContent
        }
    }

    private static func capturedBodyByteCount(of interaction: NetworkInteraction) -> Int {
        interaction.request.bodySizeBytes + (interaction.response?.bodySizeBytes ?? 0)
    }
}

private struct NetworkInteractionCaptureSignature: Equatable {
    let responseStatus: Int?
    let responseBodySizeBytes: Int?
    let responseErrorDescription: String?
    let durationMs: Int?
    let timing: NetworkTiming?

    init(_ interaction: NetworkInteraction) {
        responseStatus = interaction.response?.status
        responseBodySizeBytes = interaction.response?.bodySizeBytes
        responseErrorDescription = interaction.response?.errorDescription
        durationMs = interaction.durationMs
        timing = interaction.timing
    }
}
