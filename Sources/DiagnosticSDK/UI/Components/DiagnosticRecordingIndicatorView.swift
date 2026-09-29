import UIKit

final class DiagnosticRecordingIndicatorView: UIView {

    private enum Appearance {
        static let fillColor = UIColor.systemRed
        static let borderColor = UIColor.white
        static let borderWidth: CGFloat = 2
    }

    private enum Blink {
        static let animationKey = "com.diagnosticsdk.recordingIndicator.blink"
        static let fadeDuration: CFTimeInterval = 0.6
        static let visibleOpacity: Float = 1
        static let dimmedOpacity: Float = 0.15
        static let frameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
    }

    var isActive = false {
        didSet {
            guard isActive != oldValue else { return }
            refreshPresentation()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
        observeBlinkingConditions()
        refreshPresentation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshBlinking()
    }

    private func configureAppearance() {
        isUserInteractionEnabled = false
        backgroundColor = Appearance.fillColor
        layer.borderColor = Appearance.borderColor.cgColor
        layer.borderWidth = Appearance.borderWidth
    }

    private func observeBlinkingConditions() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(refreshBlinking),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(refreshBlinking),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    private func refreshPresentation() {
        isHidden = !isActive
        refreshBlinking()
    }

    @objc private func refreshBlinking() {
        let shouldBlink = isActive && window != nil && !UIAccessibility.isReduceMotionEnabled
        let isBlinking = layer.animation(forKey: Blink.animationKey) != nil

        if shouldBlink && !isBlinking {
            layer.add(Self.makeBlinkAnimation(), forKey: Blink.animationKey)
        } else if !shouldBlink && isBlinking {
            layer.removeAnimation(forKey: Blink.animationKey)
        }
    }

    private static func makeBlinkAnimation() -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = Blink.visibleOpacity
        animation.toValue = Blink.dimmedOpacity
        animation.duration = Blink.fadeDuration
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.preferredFrameRateRange = Blink.frameRateRange
        return animation
    }
}
