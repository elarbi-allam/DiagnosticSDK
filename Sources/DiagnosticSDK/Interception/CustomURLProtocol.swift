//
//  CustomURLProtocol.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

/// Intercepte réellement toutes les requêtes réseau
class CustomURLProtocol: URLProtocol {
    
    static var interceptor: URLSessionInterceptor?
    
    private var datatask: URLSessionDataTask?
    private var requestId: String?
    private var startTime: Date?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let interceptor = Self.interceptor else { return }
        
        startTime = Date()
        requestId = interceptor.handleRequest(request)
        
        let session = URLSession(configuration: .default)
        
        datatask = session.dataTask(with: request) { data, response, error in
            
            if let id = self.requestId, let start = self.startTime {
                interceptor.handleResponse(
                    id: id,
                    response: response,
                    data: data,
                    startTime: start
                )
            }
            
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            
            self.client?.urlProtocolDidFinishLoading(self)
        }
        
        datatask?.resume()
    }
    
    override func stopLoading() {
        datatask?.cancel()
    }
}
