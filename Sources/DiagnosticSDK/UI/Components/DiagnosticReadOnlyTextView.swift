import SwiftUI
import UIKit

struct DiagnosticReadOnlyTextView: UIViewRepresentable {
    private static let contentInset: CGFloat = 16

    let attributedText: NSAttributedString

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.dataDetectorTypes = []
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )
        textView.textContainer.lineFragmentPadding = 0
        if #available(iOS 16.0, *) {
            textView.isFindInteractionEnabled = true
        }
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        guard context.coordinator.displayedText !== attributedText else { return }
        context.coordinator.displayedText = attributedText
        textView.attributedText = attributedText
    }

    final class Coordinator {
        var displayedText: NSAttributedString?
    }
}
