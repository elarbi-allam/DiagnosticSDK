import SwiftUI

struct DiagnosticPrettyJSONLinesView: View {
    let lines: [String]
    let maxValueLength: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DiagnosticJSONTheme.lineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                jsonLineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func jsonLineView(_ line: String) -> some View {
        let indentation = DiagnosticJSONTheme.indentation(for: line)
        switch DiagnosticJSONLineParser.classify(line) {
        case .keyValue(let keyValueLine):
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(keyValueLine.quotedKey)
                    .font(DiagnosticJSONTheme.font(weight: .bold))
                    .foregroundColor(DiagnosticJSONTheme.keyColor)
                Text(":")
                    .font(DiagnosticJSONTheme.font(weight: .semibold))
                    .foregroundColor(.secondary)
                Text(truncatedPreviewText(keyValueLine.displayedValue))
                    .font(DiagnosticJSONTheme.font())
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, indentation)
        case .structural:
            Text(line)
                .font(DiagnosticJSONTheme.font(weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, indentation)
                .textSelection(.enabled)
        case .value:
            Text(truncatedPreviewText(line))
                .font(DiagnosticJSONTheme.font())
                .foregroundColor(.primary)
                .padding(.leading, indentation)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func truncatedPreviewText(_ text: String) -> String {
        guard text.count > maxValueLength else { return text }
        return String(text.prefix(maxValueLength)) + "…"
    }
}

struct DiagnosticJSONPreviewBlock: View {
    let document: DiagnosticJSONDocument
    let sheetTitle: String

    @Environment(\.diagnosticFullScreenPresenter) private var fullScreenPresenter

    private let copyActionTextGutter: CGFloat = 32

    init(document: DiagnosticJSONDocument, sheetTitle: String = "JSON") {
        self.document = document
        self.sheetTitle = sheetTitle
    }

    init(prettyJSON: String, sheetTitle: String = "JSON") {
        self.init(document: DiagnosticJSONDocument(prettyJSON: prettyJSON), sheetTitle: sheetTitle)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DiagnosticPrettyJSONLinesView(
                lines: document.previewLines,
                maxValueLength: DiagnosticJSONDocument.previewValueLengthLimit
            )
            .padding(.trailing, copyActionTextGutter)

            if document.requiresFullScreen, let fullScreenPresenter {
                DiagnosticViewFullButton {
                    fullScreenPresenter(DiagnosticFullScreenContent(title: sheetTitle, kind: .text(.json(document))))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 0.5)
        )
        .copyableOverlay(text: document.prettyJSON, accessibilityLabel: "Copy JSON")
    }
}
