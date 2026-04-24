import SwiftUI
import UIKit

final class URLCharWrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0, preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
        }
    }
}

struct URLCharacterWrappingLabel: UIViewRepresentable {
    var text: String
    var maxWidth: CGFloat
    /// 0 = unlimited
    var numberOfLines: Int
    var onHeight: (CGFloat) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> URLCharWrappingLabel {
        let labelView = URLCharWrappingLabel()
        labelView.setContentHuggingPriority(.defaultLow, for: .vertical)
        labelView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        labelView.backgroundColor = .clear
        labelView.isAccessibilityElement = true
        labelView.accessibilityLabel = "URL"
        labelView.accessibilityValue = text
        return labelView
    }
    
    func updateUIView(_ label: URLCharWrappingLabel, context: Context) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .natural
        paragraphStyle.lineSpacing = 4
        paragraphStyle.lineBreakMode = .byCharWrapping
        
        let font = UIFont.preferredFont(forTextStyle: .callout)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        label.numberOfLines = numberOfLines
        label.lineBreakMode = .byCharWrapping
        label.attributedText = NSAttributedString(string: text, attributes: attributes)
        
        if maxWidth > 0 {
            label.preferredMaxLayoutWidth = maxWidth
        }
        
        let measuredHeight = ceil(label.sizeThatFits(
            CGSize(width: max(1, maxWidth), height: .greatestFiniteMagnitude)
        ).height)
        guard context.coordinator.lastHeight != measuredHeight else { return }
        context.coordinator.lastHeight = measuredHeight
        onHeight(measuredHeight)
    }
    
    final class Coordinator {
        var lastHeight: CGFloat = -1
    }
}
