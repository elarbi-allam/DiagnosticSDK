import SwiftUI
import UIKit
import Combine

@MainActor
final class ReplayGlobalIndicatorCoordinator {
    static let shared = ReplayGlobalIndicatorCoordinator()

    private var replayCancellable: AnyCancellable?
    private var indicatorWindow: UIWindow?
    private var isStarted = false

    private init() {}

    func start(in scene: UIWindowScene? = nil) {
        guard !isStarted else { return }
        isStarted = true

        replayCancellable = Publishers.CombineLatest(
            ReplayManager.shared.$isReplayActive,
            ReplayManager.shared.$activeTrace
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isActive, trace in
            guard let self else { return }
            if isActive, trace != nil {
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
        guard let scene = preferredScene ?? resolveForegroundWindowScene() else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.backgroundColor = .clear
        window.windowLevel = .statusBar + 1

        let root = UIHostingController(rootView: ReplayGlobalIndicatorView())
        root.view.backgroundColor = .clear
        window.rootViewController = root
        window.isHidden = false
        indicatorWindow = window
    }

    private func hideIndicator() {
        guard let window = indicatorWindow else { return }
        window.isHidden = true
        indicatorWindow = nil
    }

    private func resolveForegroundWindowScene() -> UIWindowScene? {
        if let keyWindowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { scene in
                scene.activationState == .foregroundActive &&
                scene.windows.contains(where: \.isKeyWindow)
            }) {
            return keyWindowScene
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
}

private final class PassthroughWindow: UIWindow {
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

