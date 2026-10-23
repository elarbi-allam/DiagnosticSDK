import SwiftUI

struct DiagnosticURLFullScreenSheet: View {
    let title: String
    let url: String

    @Environment(\.dismiss) private var dismiss
    @State private var urlHeight: CGFloat = 0

    var body: some View {
        NavigationView {
            ScrollView {
                fullScreenURLLabel
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground))
            .copyableOverlay(text: url, accessibilityLabel: "Copy URL")
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }

    private var fullScreenURLLabel: some View {
        GeometryReader { geometryProxy in
            let availableWidth = max(0, geometryProxy.size.width)
            URLCharacterWrappingLabel(
                text: url,
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
