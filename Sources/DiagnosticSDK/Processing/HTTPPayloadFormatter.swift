import Foundation

enum FormattedHTTPBody {
    case empty
    case json(DiagnosticJSONDocument)
    case plain(String)
    case notCaptured(String)
}

enum FormattedHTTPHeaders {
    case empty
    case json(DiagnosticJSONDocument)
    case unavailable
}

enum DiagnosticJSONFormatting {
    static func prettyString(fromJSONObject jsonObject: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(jsonObject),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return nil
        }
        return String(data: prettyData, encoding: .utf8)
    }

    static func prettyString(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return prettyString(fromJSONObject: jsonObject)
    }

    static func prettyString(from raw: String) -> String? {
        prettyString(from: Data(raw.utf8))
    }

    static func prettyString(parsing possibleJSON: String) -> String? {
        if let prettyJSON = prettyString(from: possibleJSON) { return prettyJSON }
        guard let base64Data = Data(base64Encoded: possibleJSON) else { return nil }
        if let prettyJSON = prettyString(from: base64Data) { return prettyJSON }
        guard let decodedText = String(data: base64Data, encoding: .utf8) else { return nil }
        return prettyString(from: decodedText)
    }
}

enum HTTPPayloadFormatter {
    static func format(bodyData: Data?, contentType: String?) -> FormattedHTTPBody {
        guard let bodyData, !bodyData.isEmpty else { return .empty }
        let contentKind = NetworkContentType.kind(ofContentType: contentType, sniffing: bodyData)
        if contentKind == .multipart {
            return StructuredBodyFormatter.multipartSummary(from: bodyData, contentType: contentType).map(FormattedHTTPBody.plain) ?? .empty
        }
        if contentKind == .xml, let indentedXML = StructuredBodyFormatter.indentedXML(from: bodyData) {
            return .plain(indentedXML)
        }
        if let prettyJSON = DiagnosticJSONFormatting.prettyString(from: bodyData) {
            return .json(DiagnosticJSONDocument(prettyJSON: prettyJSON))
        }
        let textEncoding = NetworkContentType.textEncoding(of: contentType) ?? .utf8
        guard let text = String(data: bodyData, encoding: textEncoding) ?? String(data: bodyData, encoding: .utf8) else {
            return .empty
        }
        switch contentKind {
        case .formURLEncoded:
            return .plain(StructuredBodyFormatter.formFields(from: text) ?? text)
        case .jsonLines:
            return StructuredBodyFormatter.jsonLinesArray(from: text).map { .json(DiagnosticJSONDocument(prettyJSON: $0)) } ?? .plain(text)
        default:
            return .plain(text)
        }
    }

    static func format(text: String?) -> FormattedHTTPBody {
        guard let text, !text.isEmpty else { return .empty }
        guard let prettyJSON = DiagnosticJSONFormatting.prettyString(parsing: text) else { return .plain(text) }
        return .json(DiagnosticJSONDocument(prettyJSON: prettyJSON))
    }

    static func format(headers: [String: String]?) -> FormattedHTTPHeaders {
        guard let headers, !headers.isEmpty else { return .empty }
        guard let prettyJSON = DiagnosticJSONFormatting.prettyString(fromJSONObject: headers) else { return .unavailable }
        return .json(DiagnosticJSONDocument(prettyJSON: prettyJSON))
    }
}
