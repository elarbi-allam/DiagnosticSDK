//
//  JSONFormatter.swift
//  DiagnosticSDK
//
//  Created by ADRIA on 7/4/2026.
//

import Foundation

enum JSONFormatter {
    
    static func format(event: NetworkEvent) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(event) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
