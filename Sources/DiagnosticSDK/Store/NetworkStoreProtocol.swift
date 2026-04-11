import Foundation

/// Interface vers le module de stockage 
public protocol NetworkStoreProtocol {
    func save(event: NetworkEvent)
}
