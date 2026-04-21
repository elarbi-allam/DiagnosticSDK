import Foundation

/// Point d'entrée principal du SDK
@objc(DiagnosticSDKNetworkInterceptor)
public final class NetworkInterceptor: NSObject, NetworkInterceptorProtocol {
    
    private let interceptor: URLSessionInterceptor
    
    public init(store: NetworkStoreProtocol) {
        self.interceptor = URLSessionInterceptor(store: store)
        super.init()
        if let fileStore = store as? JSONFileStore {
            DiagnosticOverlayWindow.shared.configure(store: fileStore)
            }
    }
    
    @objc public override convenience init() {
        self.init(store: JSONFileStore())
    }
    
    @objc public func start() {
        interceptor.enable()
        ShakeDetector.shared.start()
    }
    
    @objc public func stop() {
        interceptor.disable()
    }
}
