import Foundation

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

public final class NetworkInterceptor: NSObject, NetworkInterceptorProtocol {

    private let trafficRecorder: NetworkTrafficRecording

    @objc public override convenience init() {
        self.init(store: ConsoleStore())
    }

    public init(store: NetworkStoreProtocol) {
        self.trafficRecorder = NetworkTrafficRecorder(store: store)
        super.init()
    }

    @objc public func start() {
        start(configuration: DiagnosticConfiguration.current)
    }

    public func start(configuration: DiagnosticConfiguration) {
        DiagnosticConfiguration.current = configuration

        DiagnosticSDKBootstrapper.start()
        DiagnosticSDKNetworkHooks.eventObserver = NetworkTaskObserver(recorder: trafficRecorder)
        URLProtocol.registerClass(ReplayURLProtocol.self)
        DiagnosticRuntimeState.isRunning.update(true)

        installFloatingButtonIfNeeded(configuration)

        print("✅ [DiagnosticSDK] Capture engine started (observation + replay)")
    }

    @objc public func stop() {
        DiagnosticRuntimeState.isRunning.update(false)
        URLProtocol.unregisterClass(ReplayURLProtocol.self)
        DiagnosticSDKNetworkHooks.eventObserver = nil
        trafficRecorder.interruptPendingCaptures()

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
