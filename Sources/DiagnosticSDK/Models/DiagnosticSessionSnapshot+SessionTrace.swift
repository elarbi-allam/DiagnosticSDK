import Foundation

extension DiagnosticSessionSnapshot {
    /// Builds a UI snapshot from a decoded `SessionTrace` (same shape as live `makeSnapshot()`).
    init(sessionTrace: SessionTrace) {
        let screens: [Screen] = sessionTrace.screens.map { screen in
            let interactions: [Interaction] = screen.networkInteractions.map { interaction in
                Interaction(
                    id: interaction.id,
                    startedAt: interaction.startedAt,
                    durationMs: interaction.durationMs,
                    method: interaction.request.method,
                    url: interaction.request.url,
                    status: interaction.response?.status
                )
            }
            return Screen(
                id: screen.id,
                name: screen.name,
                enteredAt: screen.enteredAt,
                exitedAt: screen.exitedAt,
                interactions: interactions
            )
        }
        self.init(
            sessionId: sessionTrace.sessionId,
            startedAt: sessionTrace.startedAt,
            metadata: Metadata(
                appVersion: sessionTrace.metadata.appVersion,
                osVersion: sessionTrace.metadata.osVersion,
                deviceModel: sessionTrace.metadata.deviceModel
            ),
            screens: screens
        )
    }
}
