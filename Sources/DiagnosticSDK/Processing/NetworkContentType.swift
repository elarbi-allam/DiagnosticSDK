import Foundation

enum NetworkContentKind: Equatable {
    case json
    case jsonLines
    case formURLEncoded
    case xml
    case html
    case multipart
    case plainText
    case image
    case binary

    var isTextual: Bool {
        switch self {
        case .json, .jsonLines, .formURLEncoded, .xml, .html, .plainText:
            return true
        case .multipart, .image, .binary:
            return false
        }
    }

    var isCapturable: Bool {
        isTextual || self == .multipart
    }

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .jsonLines: return "JSON Lines"
        case .formURLEncoded: return "Form"
        case .xml: return "XML"
        case .html: return "HTML"
        case .multipart: return "Multipart"
        case .plainText: return "Text"
        case .image: return "Image"
        case .binary: return "Binary"
        }
    }
}

enum NetworkContentType {

    private static let jsonLinesMediaTypes: Set<String> = [
        "application/x-ndjson", "application/ndjson", "application/jsonl",
        "application/x-jsonlines", "application/jsonlines"
    ]

    private static let textualApplicationMediaTypes: Set<String> = [
        "application/javascript", "application/x-javascript", "application/ecmascript",
        "application/graphql", "application/yaml", "application/x-yaml", "application/sql"
    ]

    static func isJSON(_ contentType: String?) -> Bool {
        kind(ofDeclaredContentType: contentType) == .json
    }

    static func contentTypeHeader(in headers: [String: String]?) -> String? {
        guard let headers else { return nil }
        let contentType = headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?
            .value
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let contentType, !contentType.isEmpty else { return nil }
        return contentType
    }

    static func kind(ofDeclaredContentType contentType: String?) -> NetworkContentKind? {
        guard let mediaType = mediaType(of: contentType) else { return nil }
        if jsonLinesMediaTypes.contains(mediaType) { return .jsonLines }
        if mediaType == "application/json" || mediaType == "text/json" || mediaType.hasSuffix("+json") { return .json }
        if mediaType == "application/x-www-form-urlencoded" { return .formURLEncoded }
        if mediaType == "text/html" { return .html }
        if mediaType == "application/xml" || mediaType == "text/xml" || mediaType.hasSuffix("+xml") { return .xml }
        if mediaType.hasPrefix("multipart/") { return .multipart }
        if mediaType.hasPrefix("image/") { return .image }
        if mediaType.hasPrefix("text/") || textualApplicationMediaTypes.contains(mediaType) { return .plainText }
        return .binary
    }

    static func kind(ofContentType contentType: String?, sniffing data: Data?) -> NetworkContentKind {
        if let declaredKind = kind(ofDeclaredContentType: contentType) {
            return declaredKind
        }
        return sniffedKind(of: data)
    }

    static func textEncoding(of contentType: String?) -> String.Encoding? {
        guard let contentType else { return nil }
        let charsetName = contentType
            .split(separator: ";")
            .dropFirst()
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.lowercased().hasPrefix("charset=") }?
            .dropFirst("charset=".count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard let charsetName, !charsetName.isEmpty else { return nil }
        let coreFoundationEncoding = CFStringConvertIANACharSetNameToEncoding(charsetName as CFString)
        guard coreFoundationEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(coreFoundationEncoding))
    }

    private static func mediaType(of contentType: String?) -> String? {
        let mediaType = contentType?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let mediaType, !mediaType.isEmpty else { return nil }
        return mediaType
    }

    private static func sniffedKind(of data: Data?) -> NetworkContentKind {
        guard let data, !data.isEmpty, !data.contains(0), let text = String(data: data, encoding: .utf8) else {
            return .binary
        }
        let leadingCharacter = text.first { !$0.isWhitespace }
        if leadingCharacter == "{" || leadingCharacter == "[" {
            return .json
        }
        if leadingCharacter == "<" {
            return .xml
        }
        return .plainText
    }
}
