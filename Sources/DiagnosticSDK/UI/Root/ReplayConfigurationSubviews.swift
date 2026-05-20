import SwiftUI
import Combine

struct ReplayGroupHeaderView: View {
    let group: ReplayInteractionGroup

    var body: some View {
        HStack(spacing: 8) {
            Text(group.path)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 12)

            if group.interactions.count > 1 {
                Text("×\(group.interactions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .textCase(nil)
    }
}

struct ReplayInteractionToggleRow: View {
    let interaction: ReplayInteractionItem
    let isStrictMode: Bool
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(interaction.method)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    Text(interaction.startedAt.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(interaction.hostAndPath)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                if isStrictMode, let query = interaction.queryDisplayLine {
                    Text(query)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
