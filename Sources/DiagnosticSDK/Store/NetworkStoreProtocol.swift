import Foundation

/// Interface for the storage module
public protocol NetworkStoreProtocol {
    func save(event: NetworkEvent)
}

//extension NetworkStoreProtocol {
//    
//    /// Empty default implementation.
//    /// Makes the "save" method optional for classes adopting the protocol.
//    public func save(event: NetworkEvent) {
//        // Do nothing by default.
//    }
//}
