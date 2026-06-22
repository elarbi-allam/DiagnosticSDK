import SwiftUI

struct DiagnosticRootTabView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            NavigationView {
                LiveSessionView()
                    .navigationBarTitle("Diagnostic", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Text("Fermer").bold()
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Live", systemImage: "waveform.path.ecg")
            }
            
            NavigationView {
                SessionHistoryView()
                    .navigationBarTitle("Diagnostic", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Text("Fermer").bold()
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationView {
                ReplayConfigurationView()
                    .navigationBarTitle("Diagnostic", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                dismiss()
                            } label: {
                                Text("Fermer").bold()
                            }
                        }
                    }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Replay", systemImage: "play.rectangle.on.rectangle")
            }
        }
        .onAppear {
            ReplayGlobalIndicatorCoordinator.shared.start()
        }
        .onDisappear {
            ReplayGlobalIndicatorCoordinator.shared.stop()
        }
    }
}
