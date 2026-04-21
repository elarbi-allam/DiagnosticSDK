//
//  DiagnosticOverlayWindow.swift
//  DiagnosticSDK
//
//  Created by wiame on 17/4/2026.
//
import UIKit

/// A UIWindow that floats above the host app.
/// Created lazily on first shake — zero cost until then.
public final class DiagnosticOverlayWindow: UIWindow {

    public static let shared = DiagnosticOverlayWindow()

    private var store = JSONFileStore()

    private init() {
        if #available(iOS 13, *) {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first {
                super.init(windowScene: scene)
            } else {
                super.init(frame: UIScreen.main.bounds)
            }
        } else {
            super.init(frame: UIScreen.main.bounds)
        }
        windowLevel = .statusBar + 1
        backgroundColor = .clear
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    public func configure(store: JSONFileStore) {
        self.store = store
    }

    public func show() {
        attachToActiveSceneIfNeeded()

        let nav = UINavigationController(
            rootViewController: RequestListViewController(store: store)
        )
        rootViewController = nav
        makeKeyAndVisible()
    }

    public func hide() {
        isHidden = true
        rootViewController = nil
    }

    private func attachToActiveSceneIfNeeded() {
        guard #available(iOS 13, *) else { return }

        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        if let activeScene, windowScene !== activeScene {
            self.windowScene = activeScene
        }

        if let sceneBounds = activeScene?.coordinateSpace.bounds {
            frame = sceneBounds
        } else {
            frame = UIScreen.main.bounds
        }
    }
}

