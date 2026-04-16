import UIKit

// En étendant UIWindow, on s'assure d'intercepter la secousse
// peu importe sur quel écran l'utilisateur se trouve.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            DiagnosticUIManager.shared.presentDashboard()
        }
    }
}
