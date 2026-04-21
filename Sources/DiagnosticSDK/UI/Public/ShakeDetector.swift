import UIKit

/// Intercepts shake motion events at window level.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            DiagnosticUIManager.shared.presentDashboard()
        }
    }
}
