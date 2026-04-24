import SwiftUI
import Foundation
import UIKit

struct LiveSessionView: View {
    @StateObject private var viewModel = LiveSessionViewModel()
    @State private var isExportOptionsPresented = false
    @State private var isSafeExportDialogPresented = false
    @State private var safeExportPassword = ""
    
    var body: some View {
        VStack(spacing: 0) {
            liveControlsBar
            
            Group {
                if viewModel.snapshot.screens.isEmpty {
                    DiagnosticEmptyStateView(
                        title: "No captured traffic yet",
                        systemImage: "bolt.horizontal.circle",
                        message: "Start using the app to see screens and network calls appear here."
                    )
                } else {
                    List {
                        TraceSessionHeaderSection(
                            sessionTitle: "Live session",
                            sessionId: viewModel.snapshot.sessionId,
                            startedAt: viewModel.snapshot.startedAt,
                            metadata: viewModel.snapshot.metadata
                        )
                        
                        TraceSessionFilterBarSection(
                            statusFilter: $viewModel.statusFilter,
                            methodFilter: $viewModel.methodFilter
                        )
                        
                        ForEach(viewModel.filteredScreens) { screen in
                            Section(header: TraceScreenSectionHeader(screen: screen)) {
                                ForEach(screen.interactions.reversed()) { interaction in
                                    NavigationLink {
                                        NetworkInteractionDetailView(interactionId: interaction.id)
                                    } label: {
                                        TraceNetworkInteractionRow(interaction: interaction)
                                    }
                                    .id(interaction.id)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
                }
            }
        }
        .navigationBarItems(leading: exportButton)
        .confirmationDialog("Choose export type", isPresented: $isExportOptionsPresented, titleVisibility: .visible) {
            Button("Export") {
                viewModel.exportCurrentSession()
            }
            Button("Safe Export") {
                safeExportPassword = ""
                isSafeExportDialogPresented = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $viewModel.shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert("Safe Export", isPresented: $isSafeExportDialogPresented) {
            SecureField("Password", text: $safeExportPassword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            Button("Cancel", role: .cancel) {
                safeExportPassword = ""
            }
            Button("Export") {
                viewModel.exportCurrentSessionSafely(password: safeExportPassword)
                safeExportPassword = ""
            }
            .disabled(safeExportPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a password to encrypt the exported file.")
        }
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { viewModel.exportErrorMessage != nil },
                set: { if !$0 { viewModel.exportErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.exportErrorMessage = nil
                }
            },
            message: {
                Text(viewModel.exportErrorMessage ?? "")
            }
        )
    }
    
    private var liveControlsBar: some View {
        HStack(spacing: 12) {
            Label("Total Requests: \(viewModel.totalRequests)", systemImage: "network")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button("Clear", role: .destructive) {
                viewModel.clearCurrentSession()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
    
    private var exportButton: some View {
        Button {
            isExportOptionsPresented = true
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Export current session")
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
