import SwiftUI

struct DiagnosticFullScreenContent: Identifiable {
    enum Kind {
        case text(DiagnosticFullScreenText)
        case url(String)
    }

    let id = UUID()
    let title: String
    let kind: Kind
}

struct DiagnosticFullScreenPresenter {
    fileprivate let present: (DiagnosticFullScreenContent) -> Void

    func callAsFunction(_ content: DiagnosticFullScreenContent) {
        present(content)
    }
}

private struct DiagnosticFullScreenPresenterKey: EnvironmentKey {
    static let defaultValue: DiagnosticFullScreenPresenter? = nil
}

extension EnvironmentValues {
    var diagnosticFullScreenPresenter: DiagnosticFullScreenPresenter? {
        get { self[DiagnosticFullScreenPresenterKey.self] }
        set { self[DiagnosticFullScreenPresenterKey.self] = newValue }
    }
}

private struct DiagnosticFullScreenPresentingModifier: ViewModifier {
    @State private var presentedContent: DiagnosticFullScreenContent?

    func body(content: Content) -> some View {
        content
            .environment(\.diagnosticFullScreenPresenter, DiagnosticFullScreenPresenter { presentedContent = $0 })
            .sheet(item: $presentedContent) { fullScreenContent in
                switch fullScreenContent.kind {
                case .text(let text):
                    DiagnosticFullScreenTextSheet(title: fullScreenContent.title, text: text)
                case .url(let url):
                    DiagnosticURLFullScreenSheet(title: fullScreenContent.title, url: url)
                }
            }
    }
}

struct DiagnosticViewFullButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("View full")
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderless)
    }
}

extension View {
    func presentsDiagnosticFullScreenContent() -> some View {
        modifier(DiagnosticFullScreenPresentingModifier())
    }
}
