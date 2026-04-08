//
//  NetworkInterceptorProtocol.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//
import Foundation

// Protocole exposé pour contrôler le moteur de capture
public protocol NetworkInterceptorProtocol {
    func start()
    func stop()
}

