import SwiftUI
import UIKit

enum DiagnosticJSONTheme {
    static let fontSize: CGFloat = 12
    static let lineSpacing: CGFloat = 4
    static let indentationPerLeadingSpace: CGFloat = 3.5
    static let keyUIColor = UIColor(red: 0.12, green: 0.38, blue: 0.72, alpha: 1)

    static var keyColor: Color {
        Color(keyUIColor)
    }

    static func font(weight: Font.Weight = .regular) -> Font {
        .system(size: fontSize, weight: weight, design: .monospaced)
    }

    static func uiFont(weight: UIFont.Weight = .regular) -> UIFont {
        .monospacedSystemFont(ofSize: fontSize, weight: weight)
    }

    static func indentation(for line: String) -> CGFloat {
        CGFloat(DiagnosticJSONLineParser.leadingSpaceCount(of: line)) * indentationPerLeadingSpace
    }
}
