import Foundation

/// I created this context manager as a central source of truth for the SDK's current state.
/// It tracks the active screen so I can attach this context to asynchronous network events later.
@objc(DiagnosticContext)
public final class DiagnosticContext: NSObject {
    
    /// The shared instance accessible from both Swift and Objective-C modules.
    @objc public static let shared = DiagnosticContext()
    
    /// Holds the name of the currently visible screen.
    /// I made it private(set) to ensure it can only be modified through the official update method.
    @objc public private(set) var currentScreen: String?
    
    private override init() {
        super.init()
    }
    
    /// I added this method so the Objective-C swizzling engine can safely update the screen state
    /// whenever a viewDidAppear event is triggered in the host app.
    @objc public func updateCurrentScreen(_ screenName: String) {
        self.currentScreen = screenName
    }
}
