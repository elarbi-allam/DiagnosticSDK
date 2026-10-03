import UIKit

@MainActor
final class HostWindowStackObserver {

    private let onHostWindowStackChange: @MainActor () -> Void
    private var notificationObservers: [NSObjectProtocol] = []

    init(onHostWindowStackChange: @escaping @MainActor () -> Void) {
        self.onHostWindowStackChange = onHostWindowStackChange
    }

    func start() {
        guard notificationObservers.isEmpty else { return }
        notificationObservers = [
            observeVisibilityChange(named: UIWindow.didBecomeVisibleNotification),
            observeVisibilityChange(named: UIWindow.didBecomeHiddenNotification)
        ]
    }

    func stop() {
        for notificationObserver in notificationObservers {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
        notificationObservers.removeAll()
    }

    private func observeVisibilityChange(named notificationName: Notification.Name) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: .main) { [weak self] notification in
            let changedWindow = notification.object as? UIWindow
            Task { @MainActor [weak self] in
                self?.handleVisibilityChange(of: changedWindow)
            }
        }
    }

    private func handleVisibilityChange(of changedWindow: UIWindow?) {
        guard let changedWindow, HostWindowCatalog.isHostWindow(changedWindow) else { return }
        onHostWindowStackChange()
    }
}
