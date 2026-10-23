import Foundation

protocol NetworkTrafficRecording: AnyObject {
    func recordStart(of pendingCapture: PendingNetworkCapture)

    func record(
        _ completedCapture: CompletedNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        isMocked: Bool
    )

    func recordLateMetrics(_ metrics: TaskMetricsSnapshot, for timingContext: FinishedCaptureTimingContext)

    func interruptPendingCaptures()
}

final class NetworkTrafficRecorder: NetworkTrafficRecording {

    private let store: NetworkStoreProtocol
    private let sessionStore: DiagnosticSessionStore

    init(store: NetworkStoreProtocol, sessionStore: DiagnosticSessionStore = .shared) {
        self.store = store
        self.sessionStore = sessionStore
    }

    func recordStart(of pendingCapture: PendingNetworkCapture) {
        sessionStore.beginInteraction(NetworkInteractionStart(
            id: pendingCapture.id,
            startedAt: pendingCapture.startDate,
            request: pendingCapture.request,
            screenName: pendingCapture.screenName,
            screenVisitId: pendingCapture.screenVisitId
        ))
    }

    func record(
        _ completedCapture: CompletedNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        isMocked: Bool
    ) {
        let pendingCapture = completedCapture.pendingCapture
        let timing = NetworkTimingBuilder.makeTiming(
            startUptime: pendingCapture.startUptime,
            transferEndUptime: completedCapture.transferEndUptime,
            metrics: completedCapture.metrics
        )
        var event = NetworkEventBuilder.build(
            request: pendingCapture.request,
            response: response,
            data: responseBody,
            captureId: pendingCapture.id,
            startedAt: pendingCapture.startDate,
            timing: timing,
            screenName: pendingCapture.screenName,
            screenVisitId: pendingCapture.screenVisitId,
            error: error
        )
        event.isMocked = isMocked

        sessionStore.save(event: event)
        store.save(event: event)
    }

    func recordLateMetrics(_ metrics: TaskMetricsSnapshot, for timingContext: FinishedCaptureTimingContext) {
        let timing = NetworkTimingBuilder.makeTiming(
            startUptime: timingContext.startUptime,
            transferEndUptime: timingContext.transferEndUptime,
            metrics: metrics
        )
        sessionStore.updateTiming(timing, forInteractionId: timingContext.captureId)
    }

    func interruptPendingCaptures() {
        sessionStore.interruptPendingInteractions()
    }
}
