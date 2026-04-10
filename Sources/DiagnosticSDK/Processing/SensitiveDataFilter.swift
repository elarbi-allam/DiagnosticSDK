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
