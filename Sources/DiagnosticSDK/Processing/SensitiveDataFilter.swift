import Foundation

enum SensitiveDataFilter {
    
    static func sanitize(headers: [String: String]) -> [String: String] {
        var filtered = headers

        let blockedHeaderNames: Set<String> = [
            "authorization",
            "cookie",
            "set-cookie",
            "x-api-key",
            "proxy-authorization"
        ]

        for key in filtered.keys {
            if blockedHeaderNames.contains(key.lowercased()) {
                filtered[key] = "***"
            }
        }

        return filtered
    }
}
