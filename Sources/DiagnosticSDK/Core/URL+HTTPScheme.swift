import Foundation

extension URL {

    private static let httpSchemes: Set<String> = ["http", "https"]

    var usesHTTPScheme: Bool {
        guard let scheme = scheme?.lowercased() else { return false }
        return Self.httpSchemes.contains(scheme)
    }
}
