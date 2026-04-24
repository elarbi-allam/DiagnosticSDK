import SwiftUI
import UIKit

private struct CopiedToastView: View {
    var body: some View {
        Text("Copied")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color(.systemGreen).opacity(0.92))
            )
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

private struct CopyToastModifier: ViewModifier {
    let copiedText: String
    let accessibilityLabel: String
    
    @State private var showCopied = false
    
    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            
            Button {
                UIPasteboard.general.string = copiedText
                withAnimation { showCopied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { showCopied = false }
                }
            } label: {
                Image(systemName: "doc.on.doc")
                    .imageScale(.medium)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .padding(12)
            
            if showCopied {
                VStack {
                    CopiedToastView()
                    Spacer()
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: showCopied)
    }
}

extension View {
    func copyableOverlay(text: String, accessibilityLabel: String) -> some View {
        modifier(CopyToastModifier(copiedText: text, accessibilityLabel: accessibilityLabel))
    }
}
