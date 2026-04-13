import Foundation

/// Point d'entrée principal du SDK
public final class NetworkInterceptor: NetworkInterceptorProtocol {
    
    private let interceptor: URLSessionInterceptor
    
    public init(store: NetworkStoreProtocol) {
        self.interceptor = URLSessionInterceptor(store: store)
    }
    
    public func start() {
        interceptor.enable()
    }
    
    public func stop() {
        interceptor.disable()
    }
}
