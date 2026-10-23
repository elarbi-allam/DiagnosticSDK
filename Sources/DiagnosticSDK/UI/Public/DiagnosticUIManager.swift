import UIKit
import SwiftUI

public final class DiagnosticUIManager {
    
    public static let shared = DiagnosticUIManager()

    /// Guards against queueing several deferred presentations when the trigger
    /// fires repeatedly during a transition.
    private var isPresentationScheduled = false
    
    private init() {}
    
    /// Presents the diagnostic dashboard above the current application UI.
    ///
    /// If another controller is being presented or dismissed at that very moment
    /// (another inspector reacting to the same shake, an alert, any animation),
    /// the presentation is postponed until that transition completes instead of
    /// being forced — forcing it leaves UIKit in a broken state and freezes the app.
    public func presentDashboard() {
        attemptPresentation(allowDeferral: true)
    }

    private func attemptPresentation(allowDeferral: Bool) {
        // Resolve a window that belongs to the *host application*.
        // The diagnostic overlay window must never be used: tapping the floating
        // button makes that window key, and presenting inside it would put the
        // dashboard in a pass-through, hideable window.
        guard let window = resolveHostWindow(),
              let rootVC = window.rootViewController else {
            return
        }

        // Tapping the overlay stole key window status: give it back before presenting,
        // otherwise the keyboard and first responder land in the wrong window.
        if !window.isKeyWindow {
            window.makeKey()
        }
        
        // Avoid duplicate stackings when the trigger fires repeatedly.
        if isDashboardAlreadyPresented(from: rootVC) {
            return
        }
        
        // Present from the top-most controller to avoid stacking below an existing modal.
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }

        // A controller in the middle of a transition cannot present anything.
        if topController.isBeingPresented
            || topController.isBeingDismissed
            || topController.transitionCoordinator != nil {
            scheduleRetryIfPossible(after: topController, allowDeferral: allowDeferral)
            return
        }
        
        let dashboardView = DiagnosticDashboardView()
        let hostingController = DiagnosticDashboardHostingController(rootView: dashboardView)
        hostingController.modalPresentationStyle = .pageSheet
        
        topController.present(hostingController, animated: true)
    }

    /// Retries once, when the in-flight transition is over.
    private func scheduleRetryIfPossible(after controller: UIViewController, allowDeferral: Bool) {
        guard allowDeferral, !isPresentationScheduled else { return }
        isPresentationScheduled = true

        let retry: () -> Void = { [weak self] in
            guard let self else { return }
            self.isPresentationScheduled = false
            // A single retry: if a transition is *still* running, we simply give up
            // rather than chase it forever.
            self.attemptPresentation(allowDeferral: false)
        }

        if let coordinator = controller.transitionCoordinator {
            _ = coordinator.animate(alongsideTransition: nil) { _ in retry() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { retry() }
        }
    }

    /// Window of the host application, excluding the SDK overlay windows.
    private func resolveHostWindow() -> UIWindow? {
        let presentationHostWindowResolver = PresentationHostWindowResolver()

        return HostWindowCatalog.windowScenesByActivationPriority()
            .lazy
            .compactMap { presentationHostWindowResolver.resolvePresentationHost(among: HostWindowCatalog.hostWindows(in: $0)) }
            .first
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

/// Hosting controller of the dashboard. Its only extra responsibility is to hide
/// the floating button while the dashboard is on screen.
///
/// The button is hidden in `viewDidAppear`, never in `viewWillAppear`: a presentation
/// that UIKit refuses still runs `viewWillAppear`, which used to hide the button
/// forever since the matching `viewDidDisappear` never came.
final class DiagnosticDashboardHostingController: UIHostingController<DiagnosticDashboardView> {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DiagnosticFloatingButtonCoordinator.shared.setSuspended(true)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DiagnosticFloatingButtonCoordinator.shared.setSuspended(false)
    }
}
