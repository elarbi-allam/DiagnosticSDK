import SwiftUI

public struct DiagnosticDashboardView: View {
    // Permet de fermer la vue
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            DiagnosticRootTabView()
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
    }
}
