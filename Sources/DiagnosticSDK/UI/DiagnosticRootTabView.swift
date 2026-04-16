import SwiftUI

struct DiagnosticRootTabView: View {
    var body: some View {
        TabView {
            LiveSessionView()
                .tabItem {
                    Label("Live", systemImage: "waveform.path.ecg")
                }
            
            HistoryManagerPlaceholderView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

private struct HistoryManagerPlaceholderView: View {
    var body: some View {
        DiagnosticEmptyStateView(
            title: "History Manager",
            systemImage: "clock.arrow.circlepath",
            message: "Step 3 will list exported session files from Documents."
        )
    }
}

