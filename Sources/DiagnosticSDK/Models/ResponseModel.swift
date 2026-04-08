//
//  ResponseModel.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 8/4/2026.
//

import Foundation

struct ResponseModel: Codable {
    public let statusCode: Int
        public let headers: [String: String]?
        public let bodyBase64: String?
        public let bodySizeBytes: Int
        public let errorDescription: String?
    
    
    public init(statusCode: Int, headers: [String: String]?, bodyBase64: String?, bodySizeBytes: Int, errorDescription: String?) {
            self.statusCode = statusCode
            self.headers = headers
            self.bodyBase64 = bodyBase64
            self.bodySizeBytes = bodySizeBytes
            self.errorDescription = errorDescription
        }
}
