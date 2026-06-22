import SwiftUI

extension View {
    func copyableOverlay(text: String, accessibilityLabel: String) -> some View {
        modifier(CopyToastModifier(copiedText: text, accessibilityLabel: accessibilityLabel))
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
