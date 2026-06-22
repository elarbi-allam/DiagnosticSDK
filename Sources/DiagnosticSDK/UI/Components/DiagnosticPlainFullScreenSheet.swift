import SwiftUI

struct DiagnosticPlainFullScreenSheet: View {
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
        GeometryReader { geometryProxy in
            let availableWidth = max(0, geometryProxy.size.width)
            URLCharacterWrappingLabel(
                text: text,
                maxWidth: availableWidth,
                numberOfLines: 0
            ) { measuredHeight in
                if abs(measuredHeight - urlHeight) > 0.5 {
                    DispatchQueue.main.async { urlHeight = measuredHeight }
                }
            }
            .frame(
                width: availableWidth,
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
