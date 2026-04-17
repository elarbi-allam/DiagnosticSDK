import SwiftUI

struct DiagnosticRootTabView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        TabView {
            NavigationView {
                LiveSessionView()
                    .navigationBarTitle("Diagnostic", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                presentationMode.wrappedValue.dismiss()
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
                                presentationMode.wrappedValue.dismiss()
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
        }
    }
}
