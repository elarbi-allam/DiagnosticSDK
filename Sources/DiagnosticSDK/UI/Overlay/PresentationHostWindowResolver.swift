import UIKit

protocol PresentationHostCandidate: AnyObject {
    var windowLevel: UIWindow.Level { get }
    var isKeyWindow: Bool { get }
    var hasRootViewController: Bool { get }
    var hasPresentedViewController: Bool { get }
}

extension UIWindow: PresentationHostCandidate {

    var hasRootViewController: Bool {
        rootViewController != nil
    }

    var hasPresentedViewController: Bool {
        rootViewController?.presentedViewController != nil
    }
}

struct PresentationHostWindowResolver {

    func resolvePresentationHost<Candidate: PresentationHostCandidate>(among candidates: [Candidate]) -> Candidate? {
        let presentableCandidates = candidates.filter(\.hasRootViewController)

        return highestOverlayShowingPresentation(among: presentableCandidates)
            ?? presentableCandidates.first(where: \.isKeyWindow)
            ?? presentableCandidates.first { $0.windowLevel == .normal }
            ?? presentableCandidates.first
    }

    private func highestOverlayShowingPresentation<Candidate: PresentationHostCandidate>(
        among candidates: [Candidate]
    ) -> Candidate? {
        candidates
            .filter { $0.windowLevel.rawValue > UIWindow.Level.normal.rawValue && $0.hasPresentedViewController }
            .max { $0.windowLevel.rawValue < $1.windowLevel.rawValue }
    }
}
