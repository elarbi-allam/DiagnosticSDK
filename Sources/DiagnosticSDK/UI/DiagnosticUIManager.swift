import UIKit
import SwiftUI

public final class DiagnosticUIManager {
    
    public static let shared = DiagnosticUIManager()
    
    private init() {}
    
    /// Affiche le Dashboard de diagnostic au-dessus de l'application
    public func presentDashboard() {
        // 1. Trouver la fenêtre principale active de l'application
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }
        
        // 2. Trouver le ViewController le plus haut (pour éviter de présenter sous une modale existante)
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // 3. Éviter d'ouvrir le dashboard s'il est déjà ouvert
        if topController is UIHostingController<DiagnosticDashboardView> { return }
        
        // 4. Créer et afficher la vue
        let dashboardView = DiagnosticDashboardView()
        let hostingController = UIHostingController(rootView: dashboardView)
        hostingController.modalPresentationStyle = .pageSheet // Un bel affichage qui glisse du bas
        
        topController.present(hostingController, animated: true)
    }
}
