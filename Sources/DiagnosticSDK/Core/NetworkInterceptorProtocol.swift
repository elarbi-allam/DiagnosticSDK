import Foundation

// Protocole exposé pour contrôler le moteur de capture
public protocol NetworkInterceptorProtocol {
    func start()
    func stop()
}
