import Foundation

/// Interface for the storage module
public protocol NetworkStoreProtocol {
    func save(event: NetworkEvent)
}
