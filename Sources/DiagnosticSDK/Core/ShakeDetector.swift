//
//  ShakeDetector.swift
//  DiagnosticSDK
//
//  Created by wiame on 17/4/2026.
//

import UIKit
import ObjectiveC.runtime

/// Runtime-based shake detector that listens for motion events
/// through UIApplication event dispatch.
final class ShakeDetector {

    static let shared = ShakeDetector()
    fileprivate static var lastShakeAt: TimeInterval = 0

    private static let swizzleOnce: Void = {
        guard
            let original = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.sendEvent(_:))
            ),
            let swizzled = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.diag_sendEvent(_:))
            )
        else { return }
        method_exchangeImplementations(original, swizzled)
    }()

    private init() {}

    func start() {
        _ = Self.swizzleOnce
    }
}

private extension UIApplication {

    @objc func diag_sendEvent(_ event: UIEvent)
    {
        // Calls original sendEvent because of method swizzling.
        diag_sendEvent(event)

        guard event.type == .motion else { return }
        guard event.subtype == .motionShake else { return }
        guard DiagnosticOverlayWindow.shared.isHidden else { return }

        let now = Date().timeIntervalSince1970
        guard now - ShakeDetector.lastShakeAt > 0.5 else { return }
        ShakeDetector.lastShakeAt = now

        DiagnosticOverlayWindow.shared.show()
    }
}

