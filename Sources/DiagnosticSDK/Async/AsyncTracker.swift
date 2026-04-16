import Foundation

/// Captured request metadata kept until the response arrives.
struct PendingRequest {
    let request: URLRequest
    let screenName: String?
}

final class AsyncTracker {
    
    private var requests: [String: PendingRequest] = [:]
    private let lock = NSLock()
    
    func storeRequest(id: String, request: URLRequest, screenName: String?) {
        lock.lock()
        defer { lock.unlock() }
        requests[id] = PendingRequest(request: request, screenName: screenName)
    }
    
    /// Atomically returns and removes a pending request.
    func takeRequest(id: String) -> PendingRequest? {
        lock.lock()
        defer { lock.unlock() }
        let pending = requests[id]
        requests.removeValue(forKey: id)
        return pending
    }
    
    func removeRequest(id: String) {
        lock.lock()
        defer { lock.unlock() }
        requests.removeValue(forKey: id)
    }
}
