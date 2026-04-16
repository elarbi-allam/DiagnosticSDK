import SwiftUI
import Foundation

struct LiveSessionView: View {
    @StateObject private var viewModel = LiveSessionViewModel()
    
    var body: some View {
        Group {
            if viewModel.snapshot.screens.isEmpty {
                DiagnosticEmptyStateView(
                    title: "No captured traffic yet",
                    systemImage: "bolt.horizontal.circle",
                    message: "Start using the app to see screens and network calls appear here."
                )
            } else {
                List {
                    SessionHeaderView(
                        sessionId: viewModel.snapshot.sessionId,
                        startedAt: viewModel.snapshot.startedAt
                    )
                    
                    FilterBarSection(
                        statusFilter: $viewModel.statusFilter,
                        methodFilter: $viewModel.methodFilter
                    )
                    
                    ForEach(viewModel.filteredScreens) { screen in
                        Section(header: ScreenSectionHeader(screen: screen)) {
                            ForEach(screen.interactions.reversed()) { interaction in
                                NavigationLink {
                                    NetworkInteractionDetailView(interactionId: interaction.id)
                                } label: {
                                    NetworkInteractionRow(interaction: interaction)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
            }
        }
    }
}

private struct FilterBarSection: View {
    @Binding var statusFilter: LiveSessionViewModel.StatusFilter
    @Binding var methodFilter: LiveSessionViewModel.MethodFilter
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Status", selection: $statusFilter) {
                    ForEach(LiveSessionViewModel.StatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Picker("Method", selection: $methodFilter) {
                    ForEach(LiveSessionViewModel.MethodFilter.allCases) { filter in
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

private struct SessionHeaderView: View {
    let sessionId: String
    let startedAt: Date
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Live session")
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
            .padding(.vertical, 4)
        }
    }
}

private struct ScreenSectionHeader: View {
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

private struct NetworkInteractionRow: View {
    let interaction: DiagnosticSessionSnapshot.Interaction
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusPill(status: interaction.status)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(interaction.method.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Color.secondary.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    
                    Text(hostAndPath(from: interaction.url))
                        .font(.subheadline)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    Text(interaction.startedAt.formatted(date: .omitted, time: .standard))
                        .font(.caption)
                        .foregroundColor(Color.secondary)
                    
                    if let durationMs = interaction.durationMs {
                        Text("\(durationMs) ms")
                            .font(.caption)
                            .foregroundColor(Color.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func hostAndPath(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let host = url.host ?? urlString
        let path = url.path.isEmpty ? "/" : url.path
        return host + path
    }
}

private struct StatusPill: View {
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
