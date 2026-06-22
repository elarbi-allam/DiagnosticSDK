import UIKit
import SwiftUI

public final class DiagnosticUIManager {
    
    public static let shared = DiagnosticUIManager()
    
    private init() {}
    
    /// Presents the diagnostic dashboard above the current application UI.
    public func presentDashboard() {
        // Resolve the currently active key window and root controller.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return
        }
        
        // Avoid duplicate stackings when shake is triggered repeatedly.
        if isDashboardAlreadyPresented(from: rootVC) {
            return
        }
        
        // Present from the top-most controller to avoid stacking below an existing modal.
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        let dashboardView = DiagnosticDashboardView()
        let hostingController = UIHostingController(rootView: dashboardView)
        hostingController.modalPresentationStyle = .pageSheet
        
        topController.present(hostingController, animated: true)
    }
    
    private func isDashboardAlreadyPresented(from root: UIViewController) -> Bool {
        var current: UIViewController? = root
        while let controller = current {
            if controller is UIHostingController<DiagnosticDashboardView> {
                return true
            }
            current = controller.presentedViewController
        }
        return false
    }
}
