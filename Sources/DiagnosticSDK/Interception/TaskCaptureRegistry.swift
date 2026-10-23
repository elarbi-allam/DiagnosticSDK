import Foundation

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class TaskCaptureRegistry {

    private struct Entry {
        let task: URLSessionTask
        let pendingCapture: PendingNetworkCapture
        let channel: DiagnosticSDKTaskCaptureChannel
        var accumulatedResponseBody = Data()
        var stateObservation: NSKeyValueObservation?
        var transferEndUptime: TimeInterval?
        var metrics: TaskMetricsSnapshot?
    }

    private let lock = NSLock()
    private var entriesByTask: [ObjectIdentifier: Entry] = [:]
    private let timingContextsAwaitingMetrics = NSMapTable<URLSessionTask, FinishedCaptureTimingContext>.weakToStrongObjects()

    func beginCapture(
        _ pendingCapture: PendingNetworkCapture,
        of task: URLSessionTask,
        through channel: DiagnosticSDKTaskCaptureChannel
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let taskKey = ObjectIdentifier(task)
        guard entriesByTask[taskKey] == nil else { return false }

        entriesByTask[taskKey] = Entry(task: task, pendingCapture: pendingCapture, channel: channel)
        return true
    }

    func channel(of task: URLSessionTask) -> DiagnosticSDKTaskCaptureChannel? {
        lock.lock()
        defer { lock.unlock() }
        return entriesByTask[ObjectIdentifier(task)]?.channel
    }

    func appendResponseData(_ data: Data, to task: URLSessionTask) {
        guard NetworkContentType.isJSON(task.response?.mimeType) else { return }

        lock.lock()
        defer { lock.unlock() }

        let taskKey = ObjectIdentifier(task)
        guard entriesByTask[taskKey]?.channel == .sessionDelegate else { return }
        entriesByTask[taskKey]?.accumulatedResponseBody.append(data)
    }

    func attachStateObservation(_ stateObservation: NSKeyValueObservation, to task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let taskKey = ObjectIdentifier(task)
        guard entriesByTask[taskKey] != nil else { return false }
        entriesByTask[taskKey]?.stateObservation = stateObservation
        return true
    }

    func markTransferFinished(of task: URLSessionTask, at uptime: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        let taskKey = ObjectIdentifier(task)
        guard entriesByTask[taskKey] != nil, entriesByTask[taskKey]?.transferEndUptime == nil else { return }
        entriesByTask[taskKey]?.transferEndUptime = uptime
    }

    func attachMetrics(_ metrics: TaskMetricsSnapshot, to task: URLSessionTask) -> TaskMetricsAttachment {
        lock.lock()
        defer { lock.unlock() }

        let taskKey = ObjectIdentifier(task)
        if entriesByTask[taskKey] != nil {
            entriesByTask[taskKey]?.metrics = metrics
            return .attachedToActiveCapture
        }
        guard let timingContext = timingContextsAwaitingMetrics.object(forKey: task) else { return .ignored }
        timingContextsAwaitingMetrics.removeObject(forKey: task)
        return .receivedAfterCompletion(timingContext)
    }

    func finishCapture(of task: URLSessionTask, completedAt completionUptime: TimeInterval) -> CompletedNetworkCapture? {
        lock.lock()
        let finishedEntry = entriesByTask.removeValue(forKey: ObjectIdentifier(task))
        let transferEndUptime = finishedEntry?.transferEndUptime ?? completionUptime
        if let finishedEntry, finishedEntry.metrics == nil {
            let timingContext = FinishedCaptureTimingContext(
                captureId: finishedEntry.pendingCapture.id,
                startUptime: finishedEntry.pendingCapture.startUptime,
                transferEndUptime: transferEndUptime
            )
            timingContextsAwaitingMetrics.setObject(timingContext, forKey: task)
        }
        lock.unlock()

        guard let finishedEntry else { return nil }
        finishedEntry.stateObservation?.invalidate()

        let responseBody = finishedEntry.accumulatedResponseBody
        return CompletedNetworkCapture(
            pendingCapture: finishedEntry.pendingCapture,
            accumulatedResponseBody: responseBody.isEmpty ? nil : responseBody,
            transferEndUptime: transferEndUptime,
            metrics: finishedEntry.metrics
        )
    }
}
