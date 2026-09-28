import SwiftUI

enum DiagnosticFullScreenText {
    case json(DiagnosticJSONDocument)
    case plain(String)

    var copyableText: String? {
        guard case .json(let document) = self else { return nil }
        return document.prettyJSON
    }

    func makeAttributedText() -> NSAttributedString {
        switch self {
        case .json(let document):
            return DiagnosticAttributedTextBuilder.makeJSONText(for: document)
        case .plain(let text):
            return DiagnosticAttributedTextBuilder.makePlainText(text)
        }
    }
}

struct DiagnosticFullScreenTextSheet: View {
    let title: String
    let text: DiagnosticFullScreenText

    @Environment(\.dismiss) private var dismiss
    @State private var attributedText: NSAttributedString?

    var body: some View {
        NavigationView {
            textContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(.systemBackground))
                .navigationBarTitle(title, displayMode: .inline)
                .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
        .task { await loadAttributedTextIfNeeded() }
    }

    @ViewBuilder
    private var textContent: some View {
        if let attributedText, let copyableText = text.copyableText {
            DiagnosticReadOnlyTextView(attributedText: attributedText)
                .copyableOverlay(text: copyableText, accessibilityLabel: "Copy JSON")
        } else if let attributedText {
            DiagnosticReadOnlyTextView(attributedText: attributedText)
        } else {
            ProgressView("Formatting…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func loadAttributedTextIfNeeded() async {
        guard attributedText == nil else { return }
        let fullScreenText = text
        attributedText = await Task.detached(priority: .userInitiated) {
            fullScreenText.makeAttributedText()
        }.value
    }
}
