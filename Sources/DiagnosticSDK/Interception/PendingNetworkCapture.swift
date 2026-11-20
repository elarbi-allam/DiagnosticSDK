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
    let receivedResponseByteCount: Int
    let transferEndUptime: TimeInterval
    let metrics: TaskMetricsSnapshot?
    let deliveringURLProtocolName: String?
}

final class FinishedCaptureTimingContext {
    let captureId: String
    let startUptime: TimeInterval
    let transferEndUptime: TimeInterval
    let deliveringURLProtocolName: String?

    init(captureId: String, startUptime: TimeInterval, transferEndUptime: TimeInterval, deliveringURLProtocolName: String?) {
        self.captureId = captureId
        self.startUptime = startUptime
        self.transferEndUptime = transferEndUptime
        self.deliveringURLProtocolName = deliveringURLProtocolName
    }
}

enum TaskMetricsAttachment {
    case attachedToActiveCapture
    case receivedAfterCompletion(FinishedCaptureTimingContext)
    case ignored
}
