import SwiftUI

// MARK: - Filter bar

struct TraceSessionFilterBarSection: View {
    @Binding var statusFilter: TraceHTTPStatusFilter
    @Binding var methodFilter: TraceHTTPMethodFilter
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TraceHTTPStatusFilter.allCases) { filter in
                                Button {
                                    statusFilter = filter
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(statusFilter == filter ? .white : filter.filterColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(statusFilter == filter ? filter.filterColor : filter.filterColor.opacity(0.14))
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                Picker("Method", selection: $methodFilter) {
                    ForEach(TraceHTTPMethodFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.vertical, 4)
        } header: {
            Text("Filters")
        }
    }
}

private extension TraceHTTPStatusFilter {
    var filterColor: Color {
        switch self {
        case .all: return .gray
        case .pending: return .gray
        case .success2xx: return .green
        case .redirect3xx: return .blue
        case .client4xx: return .orange
        case .server5xx: return .red
        }
    }
}

// MARK: - Session header

struct TraceSessionHeaderSection: View {
    let sessionTitle: String
    let sessionId: String
    let startedAt: Date
    let metadata: DiagnosticSessionSnapshot.Metadata
    
    var body: some View {
        Section {
            NavigationLink {
                TraceSessionMetadataDetailView(
                    sessionId: sessionId,
                    startedAt: startedAt,
                    metadata: metadata
                )
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sessionTitle)
                        .font(.headline)
                    
                    Text("Started \(startedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.subheadline)
                        .foregroundColor(Color.secondary)
                    
                    Text(sessionId)
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct TraceSessionMetadataDetailView: View {
    let sessionId: String
    let startedAt: Date
    let metadata: DiagnosticSessionSnapshot.Metadata
    
    var body: some View {
        Form {
            Section("Session") {
                metadataRow("Session ID", sessionId)
                metadataRow("Started", startedAt.formatted(date: .abbreviated, time: .standard))
            }
            
            Section("Environment") {
                metadataRow("App Version", metadata.appVersion)
                metadataRow("OS Version", metadata.osVersion)
                metadataRow("Device Model", metadata.deviceModel)
            }
        }
        .navigationBarTitle("Session Details", displayMode: .inline)
    }
    
    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.body.weight(.medium))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Screen sections & rows

struct TraceScreenSectionHeader: View {
    let screen: DiagnosticSessionSnapshot.Screen
    
    var body: some View {
        HStack(spacing: 8) {
            Text(screen.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            
            Spacer(minLength: 12)
            
            Text("\(screen.interactions.count)")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .textCase(nil)
    }
}

struct TraceNetworkInteractionRow: View {
    let interaction: DiagnosticSessionSnapshot.Interaction
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                TraceStatusPill(status: interaction.status)
                
                Text(interaction.method.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundColor(methodAccentColor(for: interaction.method))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        methodAccentColor(for: interaction.method).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                
                if let durationMs = interaction.durationMs {
                    Text("\(durationMs) ms")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("…")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(hostAndPath(from: interaction.url))
                    .font(.subheadline)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(interaction.startedAt.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
    
    private func hostAndPath(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let host = url.host ?? urlString
        let path = url.path.isEmpty ? "/" : url.path
        return host + path
    }
    
    private func methodAccentColor(for method: String) -> Color {
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

struct TraceStatusPill: View {
    let status: Int?
    
    var body: some View {
        Text(statusText)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor, in: Capsule())
            .accessibilityLabel(accessibilityLabelText)
    }
    
    private var statusText: String {
        guard let status else { return "—" }
        return "\(status)"
    }
    
    private var statusColor: Color {
        guard let status else { return .gray }
        switch status {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default: return .red
        }
    }
    
    private var accessibilityLabelText: String {
        guard let status else { return "No response yet" }
        return "Status \(status)"
    }
}
