import SwiftUI

/// Static inspector for a saved `DiagnosticTrace_*.json` file (not a live session replay).
struct TraceInspectorView: View {
    let file: DiagnosticTraceFileInfo
    
    @StateObject private var viewModel: TraceInspectorViewModel
    
    init(file: DiagnosticTraceFileInfo) {
        self.file = file
        _viewModel = StateObject(wrappedValue: TraceInspectorViewModel(fileURL: file.url))
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.snapshot == nil {
                ProgressView("Loading trace…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = viewModel.errorMessage {
                DiagnosticEmptyStateView(
                    title: "Could not open trace",
                    systemImage: "exclamationmark.triangle",
                    message: message
                )
            } else if let snapshot = viewModel.snapshot, snapshot.screens.isEmpty {
                DiagnosticEmptyStateView(
                    title: "Empty trace",
                    systemImage: "doc.text",
                    message: "This file contains no screen or network data."
                )
            } else if viewModel.snapshot != nil {
                traceList
            } else {
                DiagnosticEmptyStateView(
                    title: "No data",
                    systemImage: "doc.text",
                    message: "Unable to load this trace."
                )
            }
        }
        .navigationBarTitle(file.fileName, displayMode: .inline)
        .onAppear {
            viewModel.load()
        }
    }
    
    @ViewBuilder
    private var traceList: some View {
        if let snapshot = viewModel.snapshot {
            List {
                TraceSessionHeaderSection(
                    sessionTitle: "Recorded trace",
                    sessionId: snapshot.sessionId,
                    startedAt: snapshot.startedAt,
                    metadata: snapshot.metadata
                )
                
                TraceSessionFilterBarSection(
                    statusFilter: $viewModel.statusFilter,
                    methodFilter: $viewModel.methodFilter
                )
                
                if viewModel.filteredScreens.isEmpty {
                    Section {
                        Text("No requests match the current filters or search.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(viewModel.filteredScreens) { screen in
                        Section(header: TraceScreenSectionHeader(screen: screen)) {
                            ForEach(screen.interactions.reversed()) { interaction in
                                NavigationLink {
                                    archivedDetail(for: interaction.id)
                                } label: {
                                    TraceNetworkInteractionRow(interaction: interaction)
                                }
                                .id(interaction.id)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
    
    @ViewBuilder
    private func archivedDetail(for id: String) -> some View {
        if let full = viewModel.interaction(for: id) {
            NetworkInteractionDetailView(archivedInteraction: full)
        } else {
            Text("Missing interaction payload.")
                .foregroundColor(.secondary)
                .navigationBarTitle("Request Detail", displayMode: .inline)
        }
    }
}
