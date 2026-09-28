import Foundation

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class NetworkTaskObserver: NSObject, DiagnosticSDKNetworkEventObserving {

    private let recorder: NetworkTrafficRecording
    private let registry: TaskCaptureRegistry
    private let screenContext: DiagnosticContext

    init(
        recorder: NetworkTrafficRecording,
        registry: TaskCaptureRegistry = TaskCaptureRegistry(),
        screenContext: DiagnosticContext = .shared
    ) {
        self.recorder = recorder
        self.registry = registry
        self.screenContext = screenContext
        super.init()
    }

    func networkTaskWillResume(_ task: URLSessionTask) {
        guard
            !DiagnosticSDKNetworkHooks.isTaskExcludedFromCapture(task),
            let pendingCapture = makePendingCapture(for: task)
        else { return }

        let channel = effectiveCaptureChannel(for: task)
        guard registry.beginCapture(pendingCapture, of: task, through: channel) else { return }
        recorder.recordStart(of: pendingCapture)

        if channel == .stateObservation {
            observeCompletion(of: task)
        }
    }

    func networkTask(_ task: URLSessionTask, didReceiveResponseData data: Data) {
        registry.appendResponseData(data, to: task)
    }

    func networkTask(_ task: URLSessionTask, didCompleteWithResponseBody responseBody: Data?, error: Error?) {
        completeCapture(of: task, responseBody: responseBody, error: error)
    }

    func networkTask(_ task: URLSessionTask, didCompleteInSessionDelegateWithError error: Error?) {
        guard registry.channel(of: task) != .completionHandler else { return }
        completeCapture(of: task, responseBody: nil, error: error)
    }

    func networkTaskDidFinishTransfer(_ task: URLSessionTask) {
        registry.markTransferFinished(of: task, at: currentUptime)
    }

    func networkTask(_ task: URLSessionTask, didFinishCollectingMetrics metrics: URLSessionTaskMetrics) {
        let metricsSnapshot = TaskMetricsSnapshot(metrics: metrics)
        guard case .receivedAfterCompletion(let timingContext) = registry.attachMetrics(metricsSnapshot, to: task) else {
            return
        }
        recorder.recordLateMetrics(metricsSnapshot, for: timingContext)
    }

    private var currentUptime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private func makePendingCapture(for task: URLSessionTask) -> PendingNetworkCapture? {
        guard var request = task.originalRequest ?? task.currentRequest, request.url?.usesHTTPScheme == true else {
            return nil
        }

        if request.httpBody == nil, let uploadBody = DiagnosticSDKNetworkHooks.uploadBody(for: task) {
            request.httpBody = uploadBody
        }

        return PendingNetworkCapture(
            id: UUID().uuidString,
            request: request,
            startDate: Date(),
            startUptime: currentUptime,
            screenName: screenContext.currentScreen,
            screenVisitId: screenContext.currentScreenVisitId
        )
    }

    private func effectiveCaptureChannel(for task: URLSessionTask) -> DiagnosticSDKTaskCaptureChannel {
        let assignedChannel = DiagnosticSDKNetworkHooks.captureChannel(for: task)
        guard assignedChannel == .sessionDelegate, task.delegate != nil else { return assignedChannel }
        return .stateObservation
    }

    private func observeCompletion(of task: URLSessionTask) {
        let stateObservation = task.observe(\.state, options: [.initial, .new]) { [weak self] observedTask, _ in
            guard observedTask.state == .completed else { return }
            self?.completeCapture(of: observedTask, responseBody: nil, error: observedTask.error)
        }

        if !registry.attachStateObservation(stateObservation, to: task) {
            stateObservation.invalidate()
        }
    }

    private func completeCapture(of task: URLSessionTask, responseBody: Data?, error: Error?) {
        guard let completedCapture = registry.finishCapture(of: task, completedAt: currentUptime) else { return }

        recorder.record(
            completedCapture,
            response: task.response,
            responseBody: responseBody ?? completedCapture.accumulatedResponseBody,
            error: error,
            isMocked: DiagnosticSDKNetworkHooks.isTaskReplayed(task)
        )
    }
}
