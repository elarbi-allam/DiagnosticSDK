import Foundation

/// Public API to control the capture lifecycle.
public protocol NetworkInterceptorProtocol {
    func start()
    func stop()
}
