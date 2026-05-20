import SwiftUI

struct ReplayConfigurationView: View {
    @StateObject private var viewModel = ReplayConfigurationViewModel()
    @ObservedObject private var replayManager = ReplayManager.shared
    @State private var displayMode: ReplayDisplayMode = .timeline

    var body: some View {
        Group {
            if !viewModel.isReplayActive {
                DiagnosticEmptyStateView(
                    title: "Replay inactive",
                    systemImage: "play.slash",
                    message: "Choose a session in History → Replay."
                )
            } else if viewModel.groups.isEmpty {
                DiagnosticEmptyStateView(
                    title: "No requests",
                    systemImage: "tray",
                    message: "This trace has no network requests."
                )
            } else {
                List {
                    replayHeaderSection

                    if displayMode == .timeline {
                        Section("Requests") {
                            ForEach(viewModel.timelineInteractions) { interaction in
                                ReplayInteractionToggleRow(
                                    interaction: interaction,
                                    isStrictMode: viewModel.isStrictMatching,
                                    isEnabled: !replayManager.disabledInteractionIDs.contains(interaction.id),
                                    onToggle: { isEnabled in
                                        viewModel.setInteractionEnabled(interaction.id, isEnabled: isEnabled)
                                    }
                                )
                            }
                        }
                    } else {
                        ForEach(viewModel.groups) { group in
                            Section {
                                ForEach(group.interactions) { interaction in
                                    ReplayInteractionToggleRow(
                                        interaction: interaction,
                                        isStrictMode: viewModel.isStrictMatching,
                                        isEnabled: !replayManager.disabledInteractionIDs.contains(interaction.id),
                                        onToggle: { isEnabled in
                                            viewModel.setInteractionEnabled(interaction.id, isEnabled: isEnabled)
                                        }
                                    )
                                }
                            } header: {
                                ReplayGroupHeaderView(group: group)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationBarTitle("Replay", displayMode: .inline)
    }

    /// Read-only replay state + current matching mode comes from ReplayManager only.
    private var replayHeaderSection: some View {
        Section {
            Toggle(
                "Replay on",
                isOn: Binding(
                    get: { viewModel.isReplayActive },
                    set: { viewModel.toggleReplayState(isOn: $0) }
                )
            )

            HStack {
                Text("Matching")
                Spacer()
                Text(viewModel.matchingModeLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("Chosen in History when you activate replay.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Picker("Sorting", selection: $displayMode) {
                Text("Timeline").tag(ReplayDisplayMode.timeline)
                Text("Grouped").tag(ReplayDisplayMode.grouped)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}
