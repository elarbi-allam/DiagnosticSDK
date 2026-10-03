import UIKit
import XCTest
@testable import DiagnosticSDK

final class OverlayWindowLevelPolicyTests: XCTestCase {

    private let hostOverlayLevel = UIWindow.Level.alert + 1
    private let levelAboveKeyboard = UIWindow.Level(rawValue: 10_000_000)

    func testFloatingButtonKeepsBaselineWhenNoHostWindowIsVisible() {
        let resolvedLevel = OverlayWindowLevelPolicy.floatingButton.resolveLevel(hostWindowLevels: [])

        XCTAssertEqual(resolvedLevel, .statusBar - 1)
    }

    func testFloatingButtonKeepsBaselineAboveRegularHostWindow() {
        let resolvedLevel = OverlayWindowLevelPolicy.floatingButton.resolveLevel(hostWindowLevels: [.normal])

        XCTAssertEqual(resolvedLevel, .statusBar - 1)
    }

    func testFloatingButtonStacksAboveHighestHostOverlayWindow() {
        let resolvedLevel = OverlayWindowLevelPolicy.floatingButton.resolveLevel(
            hostWindowLevels: [.normal, hostOverlayLevel, .statusBar]
        )

        XCTAssertEqual(resolvedLevel, hostOverlayLevel + 1)
    }

    func testFloatingButtonNeverExceedsCeiling() {
        let resolvedLevel = OverlayWindowLevelPolicy.floatingButton.resolveLevel(hostWindowLevels: [levelAboveKeyboard])

        XCTAssertEqual(resolvedLevel, OverlayWindowLevelPolicy.floatingButton.ceilingLevel)
    }

    func testReplayIndicatorStaysAboveFloatingButtonInEveryHostWindowStack() {
        let hostWindowStacks: [[UIWindow.Level]] = [
            [],
            [.normal],
            [.normal, hostOverlayLevel],
            [.normal, levelAboveKeyboard]
        ]

        for hostWindowLevels in hostWindowStacks {
            let floatingButtonLevel = OverlayWindowLevelPolicy.floatingButton.resolveLevel(hostWindowLevels: hostWindowLevels)
            let replayIndicatorLevel = OverlayWindowLevelPolicy.replayIndicator.resolveLevel(hostWindowLevels: hostWindowLevels)

            XCTAssertGreaterThan(replayIndicatorLevel.rawValue, floatingButtonLevel.rawValue)
        }
    }
}
