import Foundation

/// Gère l’interception des requêtes via URLProtocol
final class URLSessionInterceptor {
    
    private let store: NetworkStoreProtocol?
    private let tracker = AsyncTracker()
    
    init(store: NetworkStoreProtocol? = nil) {
        self.store = store
    }
    
    func enable() {
        URLProtocol.registerClass(CustomURLProtocol.self)
        CustomURLProtocol.interceptor = self
    }
    
    func disable() {
        URLProtocol.unregisterClass(CustomURLProtocol.self)
    }
    
    /// Capture requête
    func handleRequest(_ request: URLRequest) -> String {
        let id = UUID().uuidString
        tracker.storeRequest(id: id, request: request)
        return id
    }
    
    /// Capture réponse
    func handleResponse(id: String, response: URLResponse?, data: Data?, startTime: Date) {
        
        guard let request = tracker.getRequest(id: id) else { return }
        
        let latency = Date().timeIntervalSince(startTime)
        
        let event = NetworkEventBuilder.build(
            request: request,
            response: response,
            data: data,
            latency: latency
        )
        store?.save(event: event)
        
        DiagnosticSessionStore.shared.save(event: event)
        if DiagnosticContext.shared.isConsoleLoggingEnabled {
            ConsoleStore().save(event: event)
            }
    }
}
