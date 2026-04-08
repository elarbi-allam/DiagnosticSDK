//
//  NetworkEvent.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

/// Événement complet (requête + réponse)
public struct NetworkEvent: Codable {
    let request: RequestModel
    let response: ResponseModel?
    let timestamp: Date
}
