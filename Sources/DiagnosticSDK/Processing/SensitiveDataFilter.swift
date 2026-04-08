//
//  SensitiveDataFilter.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

enum SensitiveDataFilter {
    
    static func sanitize(headers: [String: String]) -> [String: String] {
        var filtered = headers
        
        if filtered["Authorization"] != nil {
            filtered["Authorization"] = "***"
        }
        
        return filtered
    }
}
