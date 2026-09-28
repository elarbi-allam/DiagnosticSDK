import Foundation

struct PendingNetworkCapture {
    let request: URLRequest
    let startDate: Date
    let screenName: String?
    let screenVisitId: Int
}

struct CompletedNetworkCapture {
    let pendingCapture: PendingNetworkCapture
    let accumulatedResponseBody: Data?
}
