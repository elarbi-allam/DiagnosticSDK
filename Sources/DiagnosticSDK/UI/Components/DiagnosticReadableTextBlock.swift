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
        return GeometryReader { geometryProxy in
            let availableWidth = max(0, geometryProxy.size.width)
            URLCharacterWrappingLabel(
                text: text,
                maxWidth: availableWidth,
                numberOfLines: lineLimit
            ) { measuredHeight in
                let capped = min(measuredHeight, capHeight)
                if abs(capped - urlMeasuredHeight) > 0.5 {
                    DispatchQueue.main.async {
                        urlMeasuredHeight = capped
                    }
                }
            }
            .frame(width: availableWidth, height: min(urlMeasuredHeight > 0 ? urlMeasuredHeight : 44, capHeight), alignment: .topLeading)
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
