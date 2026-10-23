import UIKit

enum DiagnosticAttributedTextBuilder {
    static let styledJSONCharacterLimit = 5_000_000

    private static let keyAttributes: [NSAttributedString.Key: Any] = [
        .font: DiagnosticJSONTheme.uiFont(weight: .bold),
        .foregroundColor: DiagnosticJSONTheme.keyUIColor
    ]
    private static let punctuationAttributes: [NSAttributedString.Key: Any] = [
        .font: DiagnosticJSONTheme.uiFont(weight: .semibold),
        .foregroundColor: UIColor.secondaryLabel
    ]
    private static let valueAttributes: [NSAttributedString.Key: Any] = [
        .font: DiagnosticJSONTheme.uiFont(),
        .foregroundColor: UIColor.label
    ]

    static func makeJSONText(for document: DiagnosticJSONDocument) -> NSAttributedString {
        guard document.prettyJSON.utf16.count <= styledJSONCharacterLimit else {
            return makePlainText(document.prettyJSON)
        }
        let jsonText = NSMutableAttributedString()
        var paragraphStylesByIndentation: [CGFloat: NSParagraphStyle] = [:]
        let lastLineIndex = document.lines.count - 1
        for (lineIndex, line) in document.lines.enumerated() {
            let indentation = DiagnosticJSONTheme.indentation(for: line)
            let paragraphStyle = paragraphStylesByIndentation[indentation] ?? makeJSONParagraphStyle(indentation: indentation)
            paragraphStylesByIndentation[indentation] = paragraphStyle
            let styledLine = makeStyledJSONLine(line)
            if lineIndex < lastLineIndex {
                styledLine.append(NSAttributedString(string: "\n", attributes: valueAttributes))
            }
            styledLine.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: styledLine.length))
            jsonText.append(styledLine)
        }
        return jsonText
    }

    static func makePlainText(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: valueAttributes)
    }

    private static func makeStyledJSONLine(_ line: String) -> NSMutableAttributedString {
        switch DiagnosticJSONLineParser.classify(line) {
        case .keyValue(let keyValueLine):
            let styledLine = NSMutableAttributedString(string: keyValueLine.quotedKey, attributes: keyAttributes)
            styledLine.append(NSAttributedString(string: ":", attributes: punctuationAttributes))
            styledLine.append(NSAttributedString(string: keyValueLine.displayedValue, attributes: valueAttributes))
            return styledLine
        case .structural:
            return NSMutableAttributedString(string: line, attributes: punctuationAttributes)
        case .value:
            return NSMutableAttributedString(string: line, attributes: valueAttributes)
        }
    }

    private static func makeJSONParagraphStyle(indentation: CGFloat) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = indentation
        paragraphStyle.headIndent = indentation
        paragraphStyle.paragraphSpacing = DiagnosticJSONTheme.lineSpacing
        return paragraphStyle
    }
}
