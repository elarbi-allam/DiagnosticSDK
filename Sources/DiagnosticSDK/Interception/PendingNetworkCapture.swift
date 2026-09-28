import Foundation

struct PendingNetworkCapture {
    let id: String
    let request: URLRequest
    let startDate: Date
    let startUptime: TimeInterval
    let screenName: String?
    let screenVisitId: Int
}

struct CompletedNetworkCapture {
    let pendingCapture: PendingNetworkCapture
    let accumulatedResponseBody: Data?
    let transferEndUptime: TimeInterval
    let metrics: TaskMetricsSnapshot?
}

final class FinishedCaptureTimingContext {
    let captureId: String
    let startUptime: TimeInterval
    let transferEndUptime: TimeInterval

    init(captureId: String, startUptime: TimeInterval, transferEndUptime: TimeInterval) {
        self.captureId = captureId
        self.startUptime = startUptime
        self.transferEndUptime = transferEndUptime
    }
}

enum TaskMetricsAttachment {
    case attachedToActiveCapture
    case receivedAfterCompletion(FinishedCaptureTimingContext)
    case ignored
}
