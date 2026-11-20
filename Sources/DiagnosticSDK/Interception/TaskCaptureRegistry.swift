import Foundation
import ObjectiveC

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class TaskCaptureRegistry {

    private final class Entry {
        let pendingCapture: PendingNetworkCapture
        let channel: DiagnosticSDKTaskCaptureChannel
        var accumulatedResponseBody = Data()
        var receivedResponseByteCount = 0
        var stateObservation: NSKeyValueObservation?
        var transferEndUptime: TimeInterval?
        var metrics: TaskMetricsSnapshot?

        init(pendingCapture: PendingNetworkCapture, channel: DiagnosticSDKTaskCaptureChannel) {
            self.pendingCapture = pendingCapture
            self.channel = channel
        }
    }

    private static let activeEntryKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))
    private static let timingContextAwaitingMetricsKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    private let lock = NSLock()

    func beginCapture(
        _ pendingCapture: PendingNetworkCapture,
        of task: URLSessionTask,
        through channel: DiagnosticSDKTaskCaptureChannel
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard activeEntry(of: task) == nil else { return false }
        setActiveEntry(Entry(pendingCapture: pendingCapture, channel: channel), of: task)
        return true
    }

    func channel(of task: URLSessionTask) -> DiagnosticSDKTaskCaptureChannel? {
        lock.lock()
        defer { lock.unlock() }
        return activeEntry(of: task)?.channel
    }

    func appendResponseData(_ data: Data, to task: URLSessionTask) {
        let declaredContentKind = NetworkContentType.kind(ofDeclaredContentType: task.response?.mimeType)
        let isResponseBodyCapturable = declaredContentKind?.isCapturable ?? true

        lock.lock()
        defer { lock.unlock() }

        guard let entry = activeEntry(of: task), entry.channel == .sessionDelegate else { return }
        entry.receivedResponseByteCount += data.count
        let remainingCapacity = CapturedBody.maximumStoredByteCount + 1 - entry.accumulatedResponseBody.count
        guard isResponseBodyCapturable, remainingCapacity > 0 else { return }
        entry.accumulatedResponseBody.append(data.prefix(remainingCapacity))
    }

    func attachStateObservation(_ stateObservation: NSKeyValueObservation, to task: URLSessionTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = activeEntry(of: task) else { return false }
        entry.stateObservation = stateObservation
        return true
    }

    func markTransferFinished(of task: URLSessionTask, at uptime: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = activeEntry(of: task), entry.transferEndUptime == nil else { return }
        entry.transferEndUptime = uptime
    }

    func attachMetrics(_ metrics: TaskMetricsSnapshot, to task: URLSessionTask) -> TaskMetricsAttachment {
        lock.lock()
        defer { lock.unlock() }

        if let entry = activeEntry(of: task) {
            entry.metrics = metrics
            return .attachedToActiveCapture
        }
        guard let timingContext = timingContextAwaitingMetrics(of: task) else { return .ignored }
        setTimingContextAwaitingMetrics(nil, of: task)
        return .receivedAfterCompletion(timingContext)
    }

    func finishCapture(of task: URLSessionTask, completedAt completionUptime: TimeInterval) -> CompletedNetworkCapture? {
        lock.lock()
        let finishedEntry = activeEntry(of: task)
        setActiveEntry(nil, of: task)
        let transferEndUptime = finishedEntry?.transferEndUptime ?? completionUptime
        let deliveringURLProtocolName = DiagnosticSDKNetworkHooks.deliveringURLProtocolName(for: task)
        if let finishedEntry, finishedEntry.metrics == nil {
            let timingContext = FinishedCaptureTimingContext(
                captureId: finishedEntry.pendingCapture.id,
                startUptime: finishedEntry.pendingCapture.startUptime,
                transferEndUptime: transferEndUptime,
                deliveringURLProtocolName: deliveringURLProtocolName
            )
            setTimingContextAwaitingMetrics(timingContext, of: task)
        }
        lock.unlock()

        guard let finishedEntry else { return nil }
        finishedEntry.stateObservation?.invalidate()

        let responseBody = finishedEntry.accumulatedResponseBody
        return CompletedNetworkCapture(
            pendingCapture: finishedEntry.pendingCapture,
            accumulatedResponseBody: responseBody.isEmpty ? nil : responseBody,
            receivedResponseByteCount: finishedEntry.receivedResponseByteCount,
            transferEndUptime: transferEndUptime,
            metrics: finishedEntry.metrics,
            deliveringURLProtocolName: deliveringURLProtocolName
        )
    }

    private func activeEntry(of task: URLSessionTask) -> Entry? {
        objc_getAssociatedObject(task, Self.activeEntryKey) as? Entry
    }

    private func setActiveEntry(_ entry: Entry?, of task: URLSessionTask) {
        objc_setAssociatedObject(task, Self.activeEntryKey, entry, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func timingContextAwaitingMetrics(of task: URLSessionTask) -> FinishedCaptureTimingContext? {
        objc_getAssociatedObject(task, Self.timingContextAwaitingMetricsKey) as? FinishedCaptureTimingContext
    }

    private func setTimingContextAwaitingMetrics(_ timingContext: FinishedCaptureTimingContext?, of task: URLSessionTask) {
        objc_setAssociatedObject(task, Self.timingContextAwaitingMetricsKey, timingContext, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
