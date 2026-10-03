import UIKit

enum HostWindowCatalog {

    private static let uiKitBundle = Bundle(for: UIWindow.self)

    static func foregroundWindowScene() -> UIWindowScene? {
        let windowScenes = connectedWindowScenes()

        return windowScenes.first { $0.activationState == .foregroundActive && $0.windows.contains(where: \.isKeyWindow) }
            ?? windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first { !$0.windows.isEmpty }
    }

    static func windowScenesByActivationPriority() -> [UIWindowScene] {
        connectedWindowScenes().sorted { lhs, rhs in
            lhs.activationState == .foregroundActive && rhs.activationState != .foregroundActive
        }
    }

    static func hostWindows(in windowScene: UIWindowScene) -> [UIWindow] {
        windowScene.windows.filter { !$0.isHidden && isHostWindow($0) }
    }

    static func firstHostWindowWithRootViewController() -> UIWindow? {
        connectedWindowScenes()
            .flatMap(\.windows)
            .first { isHostWindow($0) && $0.rootViewController != nil }
    }

    static func isHostWindow(_ window: UIWindow) -> Bool {
        !(window is DiagnosticOverlayWindow) && !isUIKitInternalWindow(window)
    }

    private static func isUIKitInternalWindow(_ window: UIWindow) -> Bool {
        let windowClass: AnyClass = type(of: window)
        return windowClass != UIWindow.self && Bundle(for: windowClass) == uiKitBundle
    }

    private static func connectedWindowScenes() -> [UIWindowScene] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    }
}
