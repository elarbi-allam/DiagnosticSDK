import SwiftUI
import UIKit
import Combine

@MainActor
final class ReplayGlobalIndicatorCoordinator {
    static let shared = ReplayGlobalIndicatorCoordinator(replaySessionStatus: ReplayManager.shared)

    private let replaySessionStatus: ReplaySessionStatusProviding
    private var replayCancellable: AnyCancellable?
    private var indicatorWindow: ReplayIndicatorWindow?
    private var isStarted = false
    private lazy var hostWindowStackObserver = HostWindowStackObserver { [weak self] in
        self?.restackIndicatorWindow()
    }

    private init(replaySessionStatus: ReplaySessionStatusProviding) {
        self.replaySessionStatus = replaySessionStatus
    }

    func start(in scene: UIWindowScene? = nil) {
        guard !isStarted else { return }
        isStarted = true

        replayCancellable = replaySessionStatus.replaySessionRunningPublisher
            .sink { [weak self] isReplaySessionRunning in
                guard let self else { return }
                if isReplaySessionRunning {
                    self.showIndicator(in: scene)
                } else {
                    self.hideIndicator()
                }
            }
    }

    func stop() {
        replayCancellable?.cancel()
        replayCancellable = nil
        hideIndicator()
        isStarted = false
    }

    private func showIndicator(in preferredScene: UIWindowScene?) {
        guard indicatorWindow == nil else { return }
        guard let scene = preferredScene ?? HostWindowCatalog.foregroundWindowScene() else { return }

        let window = ReplayIndicatorWindow(windowScene: scene)
        window.backgroundColor = .clear
        window.stackAboveHostWindows(using: .replayIndicator)

        let root = UIHostingController(rootView: ReplayGlobalIndicatorView())
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.isHidden = false
        indicatorWindow = window
        hostWindowStackObserver.start()
    }

    private func hideIndicator() {
        guard let window = indicatorWindow else { return }
        hostWindowStackObserver.stop()
        window.isHidden = true
        indicatorWindow = nil
    }

    private func restackIndicatorWindow() {
        indicatorWindow?.stackAboveHostWindows(using: .replayIndicator)
    }
}

private final class ReplayIndicatorWindow: UIWindow, DiagnosticOverlayWindow {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Keep the overlay fully non-interactive so it never blocks app UI.
        false
    }
}

private struct ReplayGlobalIndicatorView: View {
    private let replayRed = Color(red: 0.86, green: 0.16, blue: 0.22)

    var body: some View {
        GeometryReader { _ in
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(replayRed.opacity(0.9), lineWidth: 3)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }
}

