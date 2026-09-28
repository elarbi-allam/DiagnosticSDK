import Foundation

extension DiagnosticSessionSnapshot {
    /// Builds a UI snapshot from a decoded `SessionTrace` (same shape as live `makeSnapshot()`).
    init(sessionTrace: SessionTrace) {
        let screens: [Screen] = sessionTrace.screens.map { screen in
            Screen(
                id: screen.id,
                name: screen.name,
                enteredAt: screen.enteredAt,
                exitedAt: screen.exitedAt,
                interactions: screen.networkInteractions.map { Interaction(interaction: $0, isMocked: false) }
            )
        }
        self.init(
            sessionId: sessionTrace.sessionId,
            startedAt: sessionTrace.startedAt,
            metadata: Metadata(traceMetadata: sessionTrace.metadata),
            screens: screens
        )
    }
}

extension DiagnosticSessionSnapshot.Interaction {
    init(interaction: NetworkInteraction, isMocked: Bool) {
        self.init(
            id: interaction.id,
            startedAt: interaction.startedAt,
            durationMs: interaction.durationMs,
            method: interaction.request.method,
            url: interaction.request.url,
            status: interaction.response?.status,
            isMocked: isMocked,
            isPending: interaction.response == nil
        )
    }
}

extension DiagnosticSessionSnapshot.Metadata {
    init(traceMetadata: TraceMetadata) {
        self.init(
            appVersion: traceMetadata.appVersion,
            osVersion: traceMetadata.osVersion,
            deviceModel: traceMetadata.deviceModel,
            deviceName: DeviceModelCatalog.displayName(
                forHardwareIdentifier: traceMetadata.deviceModel,
                isSimulator: traceMetadata.isSimulator ?? false
            )
        )
    }
}
