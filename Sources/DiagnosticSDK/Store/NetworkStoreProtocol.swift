//
//  NetworkStoreProtocol.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

/// Interface vers le module de stockage (collègue)
public protocol NetworkStoreProtocol {
    func save(event: NetworkEvent)
}
