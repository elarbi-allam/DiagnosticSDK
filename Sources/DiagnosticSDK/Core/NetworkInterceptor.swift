import Foundation

// 1. Import the Obj-C module (SPM allows this internally)
#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

/// Main entry point of the SDK
public final class NetworkInterceptor: NetworkInterceptorProtocol {
    
    private let interceptor: URLSessionInterceptor
    
    public init(store: NetworkStoreProtocol = ConsoleStore()) {
        self.interceptor = URLSessionInterceptor(store: store)
    }
    
    public func start() {
        // 2. Start the Objective-C interceptors in a way that is completely transparent to the host application
#if canImport(DiagnosticSDKObjC)
        DiagnosticSDKBootstrapper.start()
#endif
        
        // 3. Start the Swift engine
        interceptor.enable()
        print("✅ [DiagnosticSDK] Capture engine started (Obj-C + Swift)")
    }
    
    public func stop() {
        interceptor.disable()
    }
    
}
