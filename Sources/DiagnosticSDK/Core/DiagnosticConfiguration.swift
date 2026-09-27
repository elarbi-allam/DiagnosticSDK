import Foundation
import UIKit

/// How the host application can open the diagnostic dashboard.
public struct DiagnosticTrigger: OptionSet, Sendable {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Shake the device to open the dashboard. Historical default.
    public static let shake = DiagnosticTrigger(rawValue: 1 << 0)

    /// A draggable floating button overlaid above the application UI.
    public static let floatingButton = DiagnosticTrigger(rawValue: 1 << 1)

    /// No automatic trigger. The dashboard is then opened by the host application
    /// itself, by calling `DiagnosticUIManager.shared.presentDashboard()`
    /// (from a hidden menu, a debug screen, a five-tap gesture…).
    public static let manualOnly: DiagnosticTrigger = []

    /// Both the shake gesture and the floating button.
    public static let all: DiagnosticTrigger = [.shake, .floatingButton]
}

/// Integration-time options of the SDK.
///
/// Every property has a default, so `NetworkInterceptor().start()` alone
/// gives a fully working setup: shake **and** floating button.
public struct DiagnosticConfiguration {

    /// Default background colour of the floating button (`#FFDE90`).
    public static let defaultFloatingButtonColor = UIColor(
        red: 1.0, green: 0xDE / 255.0, blue: 0x90 / 255.0, alpha: 1.0
    )

    /// Default icon/tint colour: dark, for a readable contrast on `#FFDE90`.
    public static let defaultFloatingButtonTintColor = UIColor(
        red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0
    )

    /// Which gestures/controls open the dashboard. Defaults to `.all`
    /// (shake **and** floating button).
    public var triggers: DiagnosticTrigger

    /// Initial centre of the floating button, in the coordinate space of the
    /// active window. `nil` restores the last position chosen by the user,
    /// or falls back to the bottom-trailing corner.
    public var floatingButtonInitialPosition: CGPoint?

    /// Persist the position the user dragged the button to, across launches.
    public var floatingButtonPersistsPosition: Bool

    /// Background colour of the floating button. Defaults to `#FFDE90`.
    public var floatingButtonColor: UIColor

    /// Colour of the icon inside the button. Defaults to a dark grey.
    public var floatingButtonTintColor: UIColor

    /// Overall opacity of the button, between 0 and 1. Defaults to `0.95`.
    public var floatingButtonOpacity: CGFloat

    /// SF Symbol shown inside the button. Defaults to `"ladybug.fill"`;
    /// an unknown name silently falls back to the built-in icon.
    public var floatingButtonSystemImageName: String

    /// Diameter of the button, in points. Defaults to `52`.
    public var floatingButtonSize: CGFloat

    /// The floating button is a visible control: by default it is only
    /// installed in `DEBUG` builds (or when `DIAGNOSTIC_SDK_FORCE_ENABLE` is
    /// defined). Set this to `true` for a QA build compiled in Release that
    /// must still show it.
    public var allowsFloatingButtonInReleaseBuilds: Bool

    public init(
        triggers: DiagnosticTrigger = .all,
        floatingButtonColor: UIColor = DiagnosticConfiguration.defaultFloatingButtonColor,
        floatingButtonTintColor: UIColor = DiagnosticConfiguration.defaultFloatingButtonTintColor,
        floatingButtonOpacity: CGFloat = 0.95,
        floatingButtonSystemImageName: String = "ladybug.fill",
        floatingButtonSize: CGFloat = 52,
        floatingButtonInitialPosition: CGPoint? = nil,
        floatingButtonPersistsPosition: Bool = true,
        allowsFloatingButtonInReleaseBuilds: Bool = false
    ) {
        self.triggers = triggers
        self.floatingButtonColor = floatingButtonColor
        self.floatingButtonTintColor = floatingButtonTintColor
        self.floatingButtonOpacity = min(max(floatingButtonOpacity, 0), 1)
        self.floatingButtonSystemImageName = floatingButtonSystemImageName
        self.floatingButtonSize = max(floatingButtonSize, 32)
        self.floatingButtonInitialPosition = floatingButtonInitialPosition
        self.floatingButtonPersistsPosition = floatingButtonPersistsPosition
        self.allowsFloatingButtonInReleaseBuilds = allowsFloatingButtonInReleaseBuilds
    }
}

/// Thread-safe storage for the active configuration.
private final class DiagnosticConfigurationBox {

    static let shared = DiagnosticConfigurationBox()

    private let lock = NSLock()
    private var value = DiagnosticConfiguration()

    var configuration: DiagnosticConfiguration {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}

extension DiagnosticConfiguration {

    /// Configuration currently in effect. Set by `NetworkInterceptor.start(configuration:)`,
    /// read from UIKit callbacks (shake) on the main thread.
    public static var current: DiagnosticConfiguration {
        get { DiagnosticConfigurationBox.shared.configuration }
        set { DiagnosticConfigurationBox.shared.configuration = newValue }
    }
}
