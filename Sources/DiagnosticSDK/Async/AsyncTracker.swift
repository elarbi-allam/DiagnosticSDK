//
//  AsyncTracker.swift
//  DiagnosticSDK
//
//  Created by wiame on 7/4/2026.
//

import Foundation

/// Gère la correspondance requête/réponse
final class AsyncTracker {
    
    private var storage: [String: URLRequest] = [:]
    
    private let queue = DispatchQueue(
        label: "network.tracker.queue",
        attributes: .concurrent
    )
    
    func storeRequest(id: String, request: URLRequest) {
        queue.async(flags: .barrier) {
            self.storage[id] = request
        }
    }
    
    func getRequest(id: String) -> URLRequest? {
        queue.sync {
            storage[id]
        }
    }
}
