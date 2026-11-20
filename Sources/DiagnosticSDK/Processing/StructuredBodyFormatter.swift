import Foundation

enum StructuredBodyFormatter {

    static func formFields(from text: String) -> String? {
        let fields = text
            .split(separator: "&", omittingEmptySubsequences: true)
            .map { field -> String in
                let keyAndValue = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let key = decodedFormComponent(keyAndValue[0])
                let value = keyAndValue.count > 1 ? decodedFormComponent(keyAndValue[1]) : ""
                return "\(key) = \(value)"
            }
        return fields.isEmpty ? nil : fields.joined(separator: "\n")
    }

    static func jsonLinesArray(from text: String) -> String? {
        let jsonObjects = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { try? JSONSerialization.jsonObject(with: Data($0.utf8), options: [.fragmentsAllowed]) }
        guard !jsonObjects.isEmpty, !jsonObjects.contains(where: { $0 == nil }) else { return nil }
        return DiagnosticJSONFormatting.prettyString(fromJSONObject: jsonObjects.compactMap { $0 })
    }

    static func indentedXML(from data: Data) -> String? {
        let parser = XMLParser(data: data)
        let indentingDelegate = XMLIndentingParserDelegate()
        parser.delegate = indentingDelegate
        guard parser.parse(), !indentingDelegate.lines.isEmpty else { return nil }
        return indentingDelegate.lines.joined(separator: "\n")
    }

    static func multipartSummary(from data: Data, contentType: String?) -> String? {
        guard let boundary = multipartBoundary(of: contentType) else { return nil }
        let delimiter = Data("--\(boundary)".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var summaries: [String] = []
        var searchRange = data.startIndex..<data.endIndex

        while let delimiterRange = data.range(of: delimiter, in: searchRange) {
            let partStart = delimiterRange.upperBound
            let nextDelimiterRange = data.range(of: delimiter, in: partStart..<data.endIndex)
            let partEnd = nextDelimiterRange?.lowerBound ?? data.endIndex
            let part = data[partStart..<partEnd]
            if let headerSeparatorRange = part.range(of: headerSeparator) {
                let headers = String(decoding: part[part.startIndex..<headerSeparatorRange.lowerBound], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let partBody = trimmingTrailingLineBreak(of: part[headerSeparatorRange.upperBound..<part.endIndex])
                summaries.append(summary(ofPartNumber: summaries.count + 1, headers: headers, body: partBody))
            }
            guard let nextDelimiterRange else { break }
            searchRange = nextDelimiterRange.lowerBound..<data.endIndex
        }
        return summaries.isEmpty ? nil : summaries.joined(separator: "\n\n")
    }

    private static func decodedFormComponent(_ component: Substring) -> String {
        let spacedComponent = component.replacingOccurrences(of: "+", with: " ")
        return spacedComponent.removingPercentEncoding ?? spacedComponent
    }

    private static func multipartBoundary(of contentType: String?) -> String? {
        guard let contentType else { return nil }
        let boundary = contentType
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.lowercased().hasPrefix("boundary=") }?
            .dropFirst("boundary=".count)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard let boundary, !boundary.isEmpty else { return nil }
        return boundary
    }

    private static func trimmingTrailingLineBreak(of body: Data) -> Data {
        let lineBreak = Data("\r\n".utf8)
        guard body.count >= lineBreak.count, body.suffix(lineBreak.count) == lineBreak else { return body }
        return body.dropLast(lineBreak.count)
    }

    private static func summary(ofPartNumber partNumber: Int, headers: String, body: Data) -> String {
        let partContentType = headers
            .components(separatedBy: .newlines)
            .first { $0.lowercased().hasPrefix("content-type:") }?
            .dropFirst("content-type:".count)
            .trimmingCharacters(in: .whitespaces)
        let partKind = NetworkContentType.kind(ofContentType: partContentType, sniffing: body)
        let renderedBody: String
        if partKind.isTextual, let text = String(data: body, encoding: .utf8) {
            renderedBody = text
        } else {
            renderedBody = "[Binary content, \(CapturedBodyPresentation.formattedByteCount(body.count))]"
        }
        return "Part \(partNumber)\n\(headers)\n\n\(renderedBody)"
    }
}

private final class XMLIndentingParserDelegate: NSObject, XMLParserDelegate {

    private static let indentationUnit = "  "

    private(set) var lines: [String] = []
    private var openingLineIndices: [Int] = []
    private var pendingText = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        appendPendingTextIfNeeded()
        let renderedAttributes = attributes
            .sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\(Self.escaped($0.value))\"" }
            .joined()
        lines.append(currentIndentation + "<\(elementName)\(renderedAttributes)>")
        openingLineIndices.append(lines.count - 1)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        pendingText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        pendingText += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""
        guard let openingLineIndex = openingLineIndices.popLast() else { return }
        if openingLineIndex == lines.count - 1 {
            lines[openingLineIndex] += Self.escaped(text) + "</\(elementName)>"
            return
        }
        if !text.isEmpty {
            lines.append(currentIndentation + Self.indentationUnit + Self.escaped(text))
        }
        lines.append(currentIndentation + "</\(elementName)>")
    }

    private var currentIndentation: String {
        String(repeating: Self.indentationUnit, count: openingLineIndices.count)
    }

    private func appendPendingTextIfNeeded() {
        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingText = ""
        guard !text.isEmpty else { return }
        lines.append(currentIndentation + Self.escaped(text))
    }

    private static func escaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
