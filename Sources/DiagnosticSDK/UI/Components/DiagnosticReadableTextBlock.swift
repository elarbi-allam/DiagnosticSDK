import SwiftUI
import UIKit

/// Readable multiline text (URLs use the system font; other text uses monospace in a light frame).
struct DiagnosticReadableTextBlock: View {
    enum Kind {
        case url
        case plain
    }
    
    let text: String
    var kind: Kind = .plain
    var sheetTitle: String = "Content"
    var maxCharactersBeforeFull: Int = 900
    var previewLineLimit: Int = 10
    
    @State private var isFullScreenPresented = false
    @State private var urlMeasuredHeight: CGFloat = 0
    
    private let copyActionTextGutter: CGFloat = 32
    
    private var needsFullScreen: Bool {
        !text.isEmpty && text.count >= maxCharactersBeforeFull
    }
    
    var body: some View {
        Group {
            if text.isEmpty {
                Text("—")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                if kind == .url {
                    urlPaddedBlock
                } else {
                    plainPaddedBlock
                }
            }
        }
    }
    
    // MARK: - URL (char-wrap + copy + toast, same as JSON)
    
    private var urlPaddedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Reserve trailing space so wrapped URL doesn’t run under the overlay copy control.
            urlPreviewBody
                .padding(.trailing, copyActionTextGutter)
            if needsFullScreen {
                Button {
                    isFullScreenPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text("View full")
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .blockChrome()
        .copyableOverlay(text: text, accessibilityLabel: "Copy URL")
        .sheet(isPresented: $isFullScreenPresented) {
            DiagnosticPlainFullScreenSheet(
                title: sheetTitle,
                text: text,
                kind: kind,
                isPresented: $isFullScreenPresented
            )
        }
    }
    
    @ViewBuilder
    private var urlPreviewBody: some View {
        if needsFullScreen {
            urlCharacterWrapArea(lineLimit: previewLineLimit)
        } else {
            urlCharacterWrapArea(lineLimit: 0)
        }
    }
    
    private func urlCharacterWrapArea(lineLimit: Int) -> some View {
        let capHeight = lineLimit == 0 ? 10_000 : max(CGFloat(12 + lineLimit * 22), 1)
        return GeometryReader { g in
            let w = max(0, g.size.width)
            URLCharacterWrappingLabel(
                text: text,
                maxWidth: w,
                numberOfLines: lineLimit
            ) { h in
                let capped = min(h, capHeight)
                if abs(capped - urlMeasuredHeight) > 0.5 {
                    DispatchQueue.main.async {
                        urlMeasuredHeight = capped
                    }
                }
            }
            .frame(width: w, height: min(urlMeasuredHeight > 0 ? urlMeasuredHeight : 44, capHeight), alignment: .topLeading)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .frame(
            height: {
                if lineLimit == 0 { return max(urlMeasuredHeight, 0) }
                return min(urlMeasuredHeight > 0 ? urlMeasuredHeight : 200, capHeight)
            }()
        )
    }
    
    // MARK: - Plain
    
    private var plainPaddedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            plainTextContent
            if needsFullScreen {
                Button {
                    isFullScreenPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text("View full")
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blockChrome()
        .sheet(isPresented: $isFullScreenPresented) {
            DiagnosticPlainFullScreenSheet(
                title: sheetTitle,
                text: text,
                kind: kind,
                isPresented: $isFullScreenPresented
            )
        }
    }
    
    @ViewBuilder
    private var plainTextContent: some View {
        if needsFullScreen {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(previewLineLimit)
        } else {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Full screen

private struct DiagnosticPlainFullScreenSheet: View {
    let title: String
    let text: String
    var kind: DiagnosticReadableTextBlock.Kind
    @Binding var isPresented: Bool
    @State private var urlHeight: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                Group {
                    switch kind {
                    case .url:
                        fullScreenURLLabel
                    case .plain:
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
            .if(kind == .url) { view in
                view.copyableOverlay(text: text, accessibilityLabel: "Copy URL")
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { isPresented = false })
        }
    }
    
    private var fullScreenURLLabel: some View {
        GeometryReader { g in
            let w = max(0, g.size.width)
            URLCharacterWrappingLabel(
                text: text,
                maxWidth: w,
                numberOfLines: 0
            ) { h in
                if abs(h - urlHeight) > 0.5 {
                    DispatchQueue.main.async { urlHeight = h }
                }
            }
            .frame(
                width: w,
                height: urlHeight > 0 ? urlHeight : 100,
                alignment: .topLeading
            )
        }
        .frame(
            minHeight: max(urlHeight, 40),
            maxHeight: .none,
            alignment: .top
        )
    }
}

// MARK: - URL: UIKit char wrapping (avoids early breaks at ? / &)

private final class URLCharWrappingLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0, preferredMaxLayoutWidth != bounds.width {
            preferredMaxLayoutWidth = bounds.width
        }
    }
}

private struct URLCharacterWrappingLabel: UIViewRepresentable {
    var text: String
    var maxWidth: CGFloat
    /// 0 = unlimited
    var numberOfLines: Int
    var onHeight: (CGFloat) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> URLCharWrappingLabel {
        let l = URLCharWrappingLabel()
        l.setContentHuggingPriority(.defaultLow, for: .vertical)
        l.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        l.backgroundColor = .clear
        l.isAccessibilityElement = true
        l.accessibilityLabel = "URL"
        l.accessibilityValue = text
        return l
    }
    
    func updateUIView(_ label: URLCharWrappingLabel, context: Context) {
        let ps = NSMutableParagraphStyle()
        ps.alignment = .natural
        ps.lineSpacing = 4
        ps.lineBreakMode = .byCharWrapping
        let font = UIFont.preferredFont(forTextStyle: .callout)
        let attr: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: ps
        ]
        label.numberOfLines = numberOfLines
        label.lineBreakMode = .byCharWrapping
        label.attributedText = NSAttributedString(string: text, attributes: attr)
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

// MARK: - Shared block chrome (padding, frame, background, stroke)

private extension View {
    func blockChrome() -> some View {
        self
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
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
