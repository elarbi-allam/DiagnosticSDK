//
//  Extensions.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

extension Dictionary where Key == AnyHashable, Value == Any {
    
    func toStringDictionary() -> [String: String] {
        var result: [String: String] = [:]
        
        for (key, value) in self {
            result["\(key)"] = "\(value)"
        }
        
        return result
    }
}
