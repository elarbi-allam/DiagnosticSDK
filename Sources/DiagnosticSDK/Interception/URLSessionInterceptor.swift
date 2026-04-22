import Foundation

/// Captures requests and responses intercepted by URLProtocol.
final class URLSessionInterceptor {
    
    private let store: NetworkStoreProtocol
    private let tracker = AsyncTracker()
    
    init(store: NetworkStoreProtocol) {
        self.store = store
    }
    
    func enable() {
        URLProtocol.registerClass(CustomURLProtocol.self)
        CustomURLProtocol.interceptor = self
    }
    
    func disable() {
        URLProtocol.unregisterClass(CustomURLProtocol.self)
        CustomURLProtocol.interceptor = nil
    }
    
    func handleRequest(_ request: URLRequest) -> String {
        let id = UUID().uuidString
        // Capture the active screen exactly when the request starts.
        let currentScreen = DiagnosticContext.shared.currentScreen
        let currentScreenVisitId = DiagnosticContext.shared.currentScreenVisitId
        tracker.storeRequest(
            id: id,
            request: request,
            screenName: currentScreen,
            screenVisitId: currentScreenVisitId
        )
        return id
    }
    
    func handleResponse(id: String, response: URLResponse?, data: Data?, startTime: Date) {
        guard let pending = tracker.takeRequest(id: id) else { return }
        let latency = Date().timeIntervalSince(startTime)

        let event = NetworkEventBuilder.build(
            request: pending.request,
            response: response,
            data: data,
            latency: latency,
            screenName: pending.screenName,
            screenVisitId: pending.screenVisitId
        )
        
        DiagnosticSessionStore.shared.save(event: event)
        store.save(event: event)
    }
    
    func discardRequest(id: String) {
        tracker.removeRequest(id: id)
    }
}
