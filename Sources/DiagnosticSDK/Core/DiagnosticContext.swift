import Foundation

/// Shared runtime context used by the interception pipeline.
@objc(DiagnosticContext)
public final class DiagnosticContext: NSObject {

    struct ScreenState {
        let screenName: String?
        let visitId: Int
    }
    
    /// The shared instance accessible from both Swift and Objective-C modules.
    @objc public static let shared = DiagnosticContext()
    
    private let lock = NSLock()
    private var _currentScreen: String?
    private var _currentScreenVisitId: Int = 0
    
    @objc public var currentScreen: String? {
        lock.lock()
        defer { lock.unlock() }
        return _currentScreen
    }
    
    public var currentScreenVisitId: Int {
        lock.lock()
        defer { lock.unlock() }
        return _currentScreenVisitId
    }

    var currentScreenState: ScreenState {
        lock.lock()
        defer { lock.unlock() }
        return ScreenState(screenName: _currentScreen, visitId: _currentScreenVisitId)
    }

    private override init() {
        super.init()
    }
    
    @objc public func updateCurrentScreen(_ screenName: String) {
        lock.lock()
        defer { lock.unlock() }
        guard screenName != _currentScreen else { return }
        _currentScreen = screenName
        _currentScreenVisitId &+= 1
    }
}
