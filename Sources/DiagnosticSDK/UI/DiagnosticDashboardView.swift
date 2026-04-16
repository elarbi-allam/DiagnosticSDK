import SwiftUI

public struct DiagnosticDashboardView: View {
    // Permet de fermer la vue
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Diagnostic SDK")
                    .font(.largeTitle)
                    .bold()
                
                Text("Le moteur UI est connecté et prêt ! 🚀")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Dashboard")
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Fermer")
                    .bold()
            })
        }
    }
}
