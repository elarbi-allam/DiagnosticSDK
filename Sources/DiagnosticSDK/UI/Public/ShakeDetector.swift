import UIKit

/// Intercepts shake motion events at window level.
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        guard motion == .motionShake,
              DiagnosticRuntimeState.isRunning.value,
              DiagnosticConfiguration.current.triggers.contains(.shake) else {
            return
        }

        DiagnosticUIManager.shared.presentDashboard()
    }
}
