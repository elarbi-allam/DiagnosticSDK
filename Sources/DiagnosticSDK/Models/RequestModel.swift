//
//  RequestModel.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//
import Foundation

/// Représente une requête HTTP
public struct RequestModel: Codable {
    let url: String
    let method: String
    let headers: [String: String]
    let body: String?
}
