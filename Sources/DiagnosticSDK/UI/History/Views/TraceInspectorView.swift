import SwiftUI

/// Static inspector for a saved diagnostic JSON file (not a live session replay).
struct TraceInspectorView: View {
    let file: DiagnosticTraceFileInfo
    
    @StateObject private var viewModel: TraceInspectorViewModel
    @State private var decryptionPassword = ""
    @State private var isPasswordPromptPresented = false
    
    init(file: DiagnosticTraceFileInfo) {
        self.file = file
        _viewModel = StateObject(wrappedValue: TraceInspectorViewModel(fileURL: file.url))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.snapshot != nil {
                historySummaryBar
            }
            
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
        }
        .navigationBarTitle(file.fileName, displayMode: .inline)
        .onAppear {
            viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.passwordPromptRequestID) { requestID in
            guard requestID > 0 else { return }
            decryptionPassword = ""
            isPasswordPromptPresented = true
        }
        .alert("Encrypted trace", isPresented: $isPasswordPromptPresented) {
            SecureField("Password", text: $decryptionPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button("Cancel", role: .cancel) {
                decryptionPassword = ""
                viewModel.cancelUnlock()
            }
            Button("Unlock") {
                viewModel.unlockEncryptedTrace(password: decryptionPassword)
                decryptionPassword = ""
            }
            .disabled(
                decryptionPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isUnlocking
            )
        } message: {
            Text(viewModel.passwordPromptMessage)
        }
    }
    
    private var historySummaryBar: some View {
        HStack(spacing: 12) {
            Label("Total Requests: \(viewModel.totalRequests)", systemImage: "network")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            if viewModel.isViewingDecryptedSafeTrace {
                Label("Safe Decrypted", systemImage: "lock.shield")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.indigo.opacity(0.14))
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
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
