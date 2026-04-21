import Foundation
import UIKit

/// Point d'entrée principal du SDK
@objc(DiagnosticSDKNetworkInterceptor)
public final class NetworkInterceptor: NSObject, NetworkInterceptorProtocol {
    
    private let interceptor: URLSessionInterceptor
    private var observers: [NSObjectProtocol] = []
    private var didEnterBackground = false
    
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
        SessionContext.shared.startNewSession()
        registerLifecycleObserversIfNeeded()
        interceptor.enable()
        ShakeDetector.shared.start()
    }
    
    @objc public func stop() {
        removeLifecycleObservers()
        interceptor.disable()
    }

    private func registerLifecycleObserversIfNeeded() {
        guard observers.isEmpty else { return }

        let center = NotificationCenter.default

        let backgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.didEnterBackground = true
        }

        let activeObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard self.didEnterBackground else { return }
            self.didEnterBackground = false
            SessionContext.shared.startNewSession()
        }

        observers = [backgroundObserver, activeObserver]
    }

    private func removeLifecycleObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
        didEnterBackground = false
    }
}
