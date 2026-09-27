import Foundation

// 1. Import the Obj-C module (SPM allows this internally)
#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

/// Main entry point of the SDK
public final class NetworkInterceptor: NetworkInterceptorProtocol {
    
    private let interceptor: URLSessionInterceptor
    
    public init(store: NetworkStoreProtocol = ConsoleStore()) {
        self.interceptor = URLSessionInterceptor(store: store)
    }
    
    /// Starts the capture engine with the configuration currently in effect
    /// (shake only, unless `DiagnosticConfiguration.current` was changed).
    public func start() {
        start(configuration: DiagnosticConfiguration.current)
    }

    /// Starts the capture engine and selects how the dashboard can be opened.
    public func start(configuration: DiagnosticConfiguration) {
        DiagnosticConfiguration.current = configuration

        // 2. Start the Objective-C interceptors in a way that is completely transparent to the host application
#if canImport(DiagnosticSDKObjC)
        DiagnosticSDKBootstrapper.start()
#endif
        
        // 3. Start the Swift engine
        interceptor.enable()

        // 4. Install the optional floating trigger
        installFloatingButtonIfNeeded(configuration)

        print("✅ [DiagnosticSDK] Capture engine started (Obj-C + Swift) — build: floating-button-3")
    }
    
    public func stop() {
        interceptor.disable()
        Task { @MainActor in
            DiagnosticFloatingButtonCoordinator.shared.stop()
        }
    }

    private func installFloatingButtonIfNeeded(_ configuration: DiagnosticConfiguration) {
        guard configuration.triggers.contains(.floatingButton) else {
            print("ℹ️ [DiagnosticSDK] Floating button not requested (triggers = \(configuration.triggers.rawValue))")
            return
        }

#if !(DEBUG || DIAGNOSTIC_SDK_FORCE_ENABLE)
        // The host asked for the button explicitly, so it is installed either way,
        // but a visible debug control in a Release build deserves a loud warning.
        print("⚠️ [DiagnosticSDK] Floating button installed in a NON-DEBUG build. "
              + "Make sure this build never ships to end users.")
#endif

        print("ℹ️ [DiagnosticSDK] Installing floating button…")
        Task { @MainActor in
            DiagnosticFloatingButtonCoordinator.shared.start()
        }
    }
}
