import Foundation

/// Captures requests and responses intercepted by URLProtocol.
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
        CustomURLProtocol.interceptor = nil
    }
    
    func handleRequest(_ request: URLRequest) -> String {
        let id = UUID().uuidString
        // 1. On capture l'écran actif EXACTEMENT au moment où la requête part
        let currentScreen = DiagnosticContext.shared.currentScreen
        tracker.storeRequest(id: id, request: request, screenName: currentScreen)
        return id
    }
    
    func handleResponse(id: String, response: URLResponse?, data: Data?) {
        guard let pending = tracker.takeRequest(id: id) else { return }

        let event = NetworkEventBuilder.build(
            request: pending.request,
            response: response,
            data: data,
            screenName: pending.screenName
        )
        
        DiagnosticSessionStore.shared.save(event: event)
        if DiagnosticContext.shared.isConsoleLoggingEnabled {
            ConsoleStore().save(event: event)
        }
        store?.save(event: event)
    }
    
    func discardRequest(id: String) {
        tracker.removeRequest(id: id)
    }
}
