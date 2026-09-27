import UIKit

/// Installs a draggable floating button in a dedicated overlay window,
/// as an alternative (or a complement) to the shake gesture.
///
/// Design constraints, in order of importance:
/// 1. The button lives in its own `UIWindow`: the host view hierarchy is never touched.
/// 2. The overlay window only accepts touches inside the button frame; every other
///    touch falls through to the application.
/// 3. The window is never made key, so the host keyboard and first responder are untouched.
@MainActor
final class DiagnosticFloatingButtonCoordinator {

    static let shared = DiagnosticFloatingButtonCoordinator()

    private var window: DiagnosticFloatingButtonWindow?
    private var observers: [NSObjectProtocol] = []
    private var isStarted = false
    private var isSuspended = false

    private init() {}

    // MARK: - Lifecycle

    /// Installs the button. Safe to call several times.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        // Observers are registered *before* the first attempt, so an activation
        // happening in between is never missed.
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    DiagnosticFloatingButtonCoordinator.shared.installWindowIfPossible()
                }
            }
        )
        // Applications without a scene manifest (legacy AppDelegate lifecycle) may
        // never post UIScene notifications: this one is always posted.
        observers.append(
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    DiagnosticFloatingButtonCoordinator.shared.installWindowIfPossible()
                }
            }
        )
        observers.append(
            center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { notification in
                let scene = notification.object as? UIWindowScene
                Task { @MainActor in
                    DiagnosticFloatingButtonCoordinator.shared.handleSceneDisconnection(scene)
                }
            }
        )

        installWindowIfPossible()

        // Last resort: `start()` is usually called from didFinishLaunching, before the
        // host window exists. If nothing has activated shortly after, try again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task { @MainActor in
                DiagnosticFloatingButtonCoordinator.shared.installWindowIfPossible()
            }
        }
    }

    func stop() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        teardownWindow()
        isStarted = false
        isSuspended = false
    }

    /// Hides the button while the dashboard itself is on screen, so it never
    /// floats above its own sheet.
    ///
    /// The *view* is hidden, never the window: hiding a window that happens to
    /// host a presentation makes the presented controller unreachable and leaves
    /// the application frozen behind an invisible overlay.
    func setSuspended(_ suspended: Bool) {
        isSuspended = suspended
        window?.rootViewController?.view.isHidden = suspended
        if suspended {
            window?.interactiveFrame = .zero
        } else {
            (window?.rootViewController as? DiagnosticFloatingButtonViewController)?
                .refreshInteractiveFrame()
        }
    }

    // MARK: - Window management

    private func installWindowIfPossible() {
        guard isStarted else { return }

        // An existing, still-valid window is kept as is.
        if let existing = window {
            let state = existing.windowScene?.activationState
            // Keep the window as long as it is attached to a usable scene.
            if state == nil || state == .foregroundActive || state == .foregroundInactive {
                return
            }
            teardownWindow()
        }

        let configuration = DiagnosticConfiguration.current
        let overlay: DiagnosticFloatingButtonWindow

        if let scene = resolveWindowScene() {
            overlay = DiagnosticFloatingButtonWindow(windowScene: scene)
        } else if let hostWindow = legacyHostWindow() {
            // Application without scenes: mirror the host window's geometry.
            overlay = DiagnosticFloatingButtonWindow(frame: hostWindow.frame)
        } else {
            // No window anywhere yet — a later activation will call us back.
            print("ℹ️ [DiagnosticSDK] Floating button: no window available yet, will retry")
            return
        }

        overlay.backgroundColor = .clear
        // Above the application content, below system alerts and the status bar.
        overlay.windowLevel = .statusBar - 1

        let controller = DiagnosticFloatingButtonViewController(configuration: configuration)
        controller.onInteractiveFrameChange = { [weak overlay] frame in
            overlay?.interactiveFrame = frame
        }
        controller.onTap = {
            DiagnosticUIManager.shared.presentDashboard()
        }

        overlay.rootViewController = controller
        // Deliberately not `makeKeyAndVisible`: the host keeps key window status.
        overlay.isHidden = false
        controller.view.isHidden = isSuspended
        window = overlay

        print("✅ [DiagnosticSDK] Floating button installed — level \(overlay.windowLevel.rawValue), "
              + "frame \(overlay.frame), scene \(String(describing: overlay.windowScene))")
    }

    /// Any window of the host application, used when no scene can be resolved.
    private func legacyHostWindow() -> UIWindow? {
        let sceneWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        return sceneWindows.first(where: { !($0 is DiagnosticFloatingButtonWindow) && $0.rootViewController != nil })
    }

    private func handleSceneDisconnection(_ scene: UIWindowScene?) {
        guard let scene, window?.windowScene === scene else { return }
        teardownWindow()
        installWindowIfPossible()
    }

    private func teardownWindow() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private func resolveWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        if let keyWindowScene = scenes.first(where: { scene in
            scene.activationState == .foregroundActive &&
            scene.windows.contains(where: \.isKeyWindow)
        }) {
            return keyWindowScene
        }

        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) {
            return activeScene
        }

        // Legacy applications (no scene manifest) expose a compatibility scene whose
        // activation state may never become `.foregroundActive`.
        return scenes.first(where: { !$0.windows.isEmpty })
    }
}

// MARK: - Overlay window

/// Overlay window that only captures touches inside `interactiveFrame`.
final class DiagnosticFloatingButtonWindow: UIWindow {

    /// Frame of the button, in window coordinates. Everything outside falls through.
    var interactiveFrame: CGRect = .zero

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard !isHidden, !interactiveFrame.isEmpty else { return false }
        return interactiveFrame.contains(point)
    }
}

// MARK: - Button

private final class DiagnosticFloatingButtonViewController: UIViewController {

    private enum Metrics {
        static let margin: CGFloat = 16
    }

    private static let positionXDefaultsKey = "com.diagnosticsdk.floatingButton.position.x"
    private static let positionYDefaultsKey = "com.diagnosticsdk.floatingButton.position.y"

    var onTap: (() -> Void)?
    var onInteractiveFrameChange: ((CGRect) -> Void)?

    private let configuration: DiagnosticConfiguration
    private var hasPositionedButton = false

    private var initialPosition: CGPoint? { configuration.floatingButtonInitialPosition }
    private var persistsPosition: Bool { configuration.floatingButtonPersistsPosition }
    private var size: CGFloat { configuration.floatingButtonSize }

    private lazy var button: UIButton = {
        let size = configuration.floatingButtonSize
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: size, height: size)
        button.backgroundColor = configuration.floatingButtonColor
        button.tintColor = configuration.floatingButtonTintColor
        button.alpha = configuration.floatingButtonOpacity
        button.layer.cornerRadius = size / 2
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.setImage(Self.resolveIcon(named: configuration.floatingButtonSystemImageName), for: .normal)
        button.accessibilityIdentifier = "diagnostic.floatingButton"
        button.accessibilityLabel = "Open diagnostics"
        button.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        return button
    }()

    /// Falls back through a chain of symbols so an unknown name never yields an empty button.
    private static func resolveIcon(named name: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        for candidate in [name, "ladybug.fill", "ladybug", "ant.fill", "waveform.path.ecg"] {
            if let image = UIImage(systemName: candidate, withConfiguration: configuration) {
                return image
            }
        }
        return nil
    }

    init(configuration: DiagnosticConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = UIView()
        container.backgroundColor = .clear
        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(button)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        button.addGestureRecognizer(pan)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !hasPositionedButton {
            hasPositionedButton = true
            button.center = clamp(resolveInitialCenter())
        } else {
            button.center = clamp(button.center)
        }
        publishInteractiveFrame()
    }

    // MARK: - Interaction

    @objc private func handleTap() {
        onTap?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)

        button.center = clamp(CGPoint(x: button.center.x + translation.x,
                                      y: button.center.y + translation.y))
        publishInteractiveFrame()

        if gesture.state == .ended || gesture.state == .cancelled {
            storePositionIfNeeded(button.center)
        }
    }

    // MARK: - Positioning

    /// Re-publishes the touchable area, e.g. after the button was un-suspended.
    func refreshInteractiveFrame() {
        publishInteractiveFrame()
    }

    private func publishInteractiveFrame() {
        // Slightly enlarged to keep a comfortable touch target.
        onInteractiveFrameChange?(button.frame.insetBy(dx: -6, dy: -6))
    }

    private func resolveInitialCenter() -> CGPoint {
        if let initialPosition {
            return initialPosition
        }
        if persistsPosition,
           let storedX = UserDefaults.standard.object(forKey: Self.positionXDefaultsKey) as? Double,
           let storedY = UserDefaults.standard.object(forKey: Self.positionYDefaultsKey) as? Double {
            return CGPoint(x: storedX, y: storedY)
        }
        let insets = view.safeAreaInsets
        return CGPoint(
            x: view.bounds.maxX - insets.right - Metrics.margin - size / 2,
            y: view.bounds.maxY - insets.bottom - Metrics.margin * 4 - size / 2
        )
    }

    private func storePositionIfNeeded(_ center: CGPoint) {
        guard persistsPosition else { return }
        UserDefaults.standard.set(Double(center.x), forKey: Self.positionXDefaultsKey)
        UserDefaults.standard.set(Double(center.y), forKey: Self.positionYDefaultsKey)
    }

    private func clamp(_ center: CGPoint) -> CGPoint {
        let insets = view.safeAreaInsets
        let half = size / 2
        let minX = view.bounds.minX + insets.left + Metrics.margin + half
        let maxX = view.bounds.maxX - insets.right - Metrics.margin - half
        let minY = view.bounds.minY + insets.top + Metrics.margin + half
        let maxY = view.bounds.maxY - insets.bottom - Metrics.margin - half

        guard minX <= maxX, minY <= maxY else { return center }
        return CGPoint(x: min(max(center.x, minX), maxX),
                       y: min(max(center.y, minY), maxY))
    }
}
