import UIKit
import XCTest
@testable import DiagnosticSDK

final class PresentationHostWindowResolverTests: XCTestCase {

    private let resolver = PresentationHostWindowResolver()

    func testPrefersHostOverlayShowingPresentationOverKeyWindow() {
        let mainWindow = PresentationHostCandidateStub(isKeyWindow: true)
        let hostOverlay = PresentationHostCandidateStub(windowLevel: .alert + 1, hasPresentedViewController: true)

        let presentationHost = resolver.resolvePresentationHost(among: [mainWindow, hostOverlay])

        XCTAssertIdentical(presentationHost, hostOverlay)
    }

    func testPrefersHighestHostOverlayShowingPresentation() {
        let lowerHostOverlay = PresentationHostCandidateStub(windowLevel: .statusBar, hasPresentedViewController: true)
        let higherHostOverlay = PresentationHostCandidateStub(windowLevel: .alert + 1, hasPresentedViewController: true)

        let presentationHost = resolver.resolvePresentationHost(among: [higherHostOverlay, lowerHostOverlay])

        XCTAssertIdentical(presentationHost, higherHostOverlay)
    }

    func testIgnoresPassiveHostOverlay() {
        let mainWindow = PresentationHostCandidateStub(isKeyWindow: true)
        let passiveHostOverlay = PresentationHostCandidateStub(windowLevel: .alert + 1)

        let presentationHost = resolver.resolvePresentationHost(among: [passiveHostOverlay, mainWindow])

        XCTAssertIdentical(presentationHost, mainWindow)
    }

    func testIgnoresPresentationOnNormalLevelWhenSelectingOverlay() {
        let keyWindow = PresentationHostCandidateStub(windowLevel: .statusBar, isKeyWindow: true)
        let mainWindowWithModal = PresentationHostCandidateStub(hasPresentedViewController: true)

        let presentationHost = resolver.resolvePresentationHost(among: [mainWindowWithModal, keyWindow])

        XCTAssertIdentical(presentationHost, keyWindow)
    }

    func testFallsBackToNormalLevelWindowWhenNoCandidateIsKey() {
        let passiveHostOverlay = PresentationHostCandidateStub(windowLevel: .alert + 1)
        let mainWindow = PresentationHostCandidateStub()

        let presentationHost = resolver.resolvePresentationHost(among: [passiveHostOverlay, mainWindow])

        XCTAssertIdentical(presentationHost, mainWindow)
    }

    func testFallsBackToFirstCandidateWhenNoneIsKeyOrNormalLevel() {
        let firstHostOverlay = PresentationHostCandidateStub(windowLevel: .statusBar)
        let secondHostOverlay = PresentationHostCandidateStub(windowLevel: .alert)

        let presentationHost = resolver.resolvePresentationHost(among: [firstHostOverlay, secondHostOverlay])

        XCTAssertIdentical(presentationHost, firstHostOverlay)
    }

    func testIgnoresCandidatesWithoutRootViewController() {
        let emptyKeyWindow = PresentationHostCandidateStub(isKeyWindow: true, hasRootViewController: false)
        let mainWindow = PresentationHostCandidateStub()

        let presentationHost = resolver.resolvePresentationHost(among: [emptyKeyWindow, mainWindow])

        XCTAssertIdentical(presentationHost, mainWindow)
    }

    func testReturnsNilWithoutCandidates() {
        let presentationHost = resolver.resolvePresentationHost(among: [PresentationHostCandidateStub]())

        XCTAssertNil(presentationHost)
    }
}

private final class PresentationHostCandidateStub: PresentationHostCandidate {

    let windowLevel: UIWindow.Level
    let isKeyWindow: Bool
    let hasRootViewController: Bool
    let hasPresentedViewController: Bool

    init(
        windowLevel: UIWindow.Level = .normal,
        isKeyWindow: Bool = false,
        hasRootViewController: Bool = true,
        hasPresentedViewController: Bool = false
    ) {
        self.windowLevel = windowLevel
        self.isKeyWindow = isKeyWindow
        self.hasRootViewController = hasRootViewController
        self.hasPresentedViewController = hasPresentedViewController
    }
}
