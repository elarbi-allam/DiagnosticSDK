//
//  NetworkEventBuilder.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

enum NetworkEventBuilder {
    
    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        latency: Double
    ) -> NetworkEvent {
        
        let filteredHeaders = SensitiveDataFilter.sanitize(
            headers: request.allHTTPHeaderFields ?? [:]
        )
        
        let requestModel = RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: filteredHeaders,
            body: request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        )
        
        let httpResponse = response as? HTTPURLResponse
        
        let responseModel = ResponseModel(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: httpResponse?.allHeaderFields as? [String: String] ?? [:],
            body: data.flatMap { String(data: $0, encoding: .utf8) },
            latency: latency
        )
        
        return NetworkEvent(
            request: requestModel,
            response: responseModel,
            timestamp: Date()
        )
    }
}
