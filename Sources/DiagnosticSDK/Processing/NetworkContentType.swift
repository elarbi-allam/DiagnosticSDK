import Foundation

enum NetworkContentType {

    static func isJSON(_ contentType: String?) -> Bool {
        guard let normalizedContentType = contentType?.lowercased() else { return false }
        return normalizedContentType.contains("application/json") || normalizedContentType.contains("+json")
    }
}
