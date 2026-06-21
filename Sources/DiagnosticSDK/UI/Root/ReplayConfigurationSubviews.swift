import SwiftUI
import Combine

struct ReplayGroupHeaderView: View {
    let group: ReplayInteractionGroup

    var body: some View {
        HStack(spacing: 8) {
            Text(group.path)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 12)

            if group.interactions.count > 1 {
                Text("×\(group.interactions.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.16), in: Capsule())
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
    let onSelectDetails: () -> Void

    private var methodColor: Color {
        ReplayHTTPMethodStyle.accentColor(for: interaction.method)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onSelectDetails) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(interaction.method)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(methodColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(methodColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                            Text(interaction.startedAt.formatted(date: .omitted, time: .standard))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Text(interaction.hostAndPath)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if isStrictMode, let query = interaction.queryDisplayLine {
                            Text(query)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.6)
            .accessibilityLabel("View request details")
            .accessibilityHint("Opens headers, body, and response for this request")

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .accessibilityLabel("Include request in replay")
        }
        .padding(.vertical, 6)
    }
}

private enum ReplayHTTPMethodStyle {
    static func accentColor(for method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "PATCH": return .purple
        case "DELETE": return .red
        case "HEAD", "OPTIONS", "CONNECT", "TRACE": return .gray
        default: return .indigo
        }
    }
}
