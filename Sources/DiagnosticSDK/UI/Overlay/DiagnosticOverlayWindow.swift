import UIKit

protocol DiagnosticOverlayWindow: UIWindow {}

extension DiagnosticOverlayWindow {

    func stackAboveHostWindows(using levelPolicy: OverlayWindowLevelPolicy) {
        let hostWindowScene = windowScene ?? HostWindowCatalog.foregroundWindowScene()
        let hostWindowLevels = hostWindowScene.map { HostWindowCatalog.hostWindows(in: $0).map(\.windowLevel) } ?? []
        let resolvedLevel = levelPolicy.resolveLevel(hostWindowLevels: hostWindowLevels)

        guard windowLevel != resolvedLevel else { return }
        windowLevel = resolvedLevel
    }
}
