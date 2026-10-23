import UIKit

struct OverlayWindowLevelPolicy {

    let baselineLevel: UIWindow.Level
    let offsetAboveHostWindows: CGFloat
    let ceilingLevel: UIWindow.Level

    func resolveLevel(hostWindowLevels: [UIWindow.Level]) -> UIWindow.Level {
        guard let highestHostRawLevel = hostWindowLevels.map(\.rawValue).max() else {
            return baselineLevel
        }
        let stackedRawLevel = max(baselineLevel.rawValue, highestHostRawLevel + offsetAboveHostWindows)
        return UIWindow.Level(rawValue: min(stackedRawLevel, ceilingLevel.rawValue))
    }
}

extension OverlayWindowLevelPolicy {

    private static let applicationOverlayCeilingLevel = UIWindow.Level.alert + 1000

    static let floatingButton = OverlayWindowLevelPolicy(
        baselineLevel: .statusBar - 1,
        offsetAboveHostWindows: 1,
        ceilingLevel: applicationOverlayCeilingLevel
    )

    static let replayIndicator = OverlayWindowLevelPolicy(
        baselineLevel: .statusBar + 1,
        offsetAboveHostWindows: 2,
        ceilingLevel: applicationOverlayCeilingLevel + 1
    )
}
