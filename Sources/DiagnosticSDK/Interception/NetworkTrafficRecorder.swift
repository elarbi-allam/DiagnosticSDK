import Foundation

protocol NetworkTrafficRecording: AnyObject {
    func record(
        _ pendingCapture: PendingNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        isMocked: Bool
    )
}

final class NetworkTrafficRecorder: NetworkTrafficRecording {

    private let store: NetworkStoreProtocol
    private let sessionStore: DiagnosticSessionStore

    init(store: NetworkStoreProtocol, sessionStore: DiagnosticSessionStore = .shared) {
        self.store = store
        self.sessionStore = sessionStore
    }

    func record(
        _ pendingCapture: PendingNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        isMocked: Bool
    ) {
        var event = NetworkEventBuilder.build(
            request: pendingCapture.request,
            response: response,
            data: responseBody,
            latency: Date().timeIntervalSince(pendingCapture.startDate),
            screenName: pendingCapture.screenName,
            screenVisitId: pendingCapture.screenVisitId,
            error: error
        )
        event.isMocked = isMocked

        sessionStore.save(event: event)
        store.save(event: event)
    }
}
