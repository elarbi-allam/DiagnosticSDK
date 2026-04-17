import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    @State private var isImportPickerPresented = false
    @State private var filePendingDeletion: DiagnosticTraceFileInfo?
    
    var body: some View {
        Group {
            if viewModel.isScanning && viewModel.files.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.files.isEmpty {
                DiagnosticEmptyStateView(
                    title: "No saved traces",
                    systemImage: "doc.text",
                    message: "Exported sessions appear here as DiagnosticTrace_*.json in Documents (for example after the app enters the background)."
                )
            } else {
                List {
                    Section {
                        historyFilterBar
                    }
                    
                    if viewModel.visibleFiles.isEmpty {
                        Section {
                            Text("No trace matches current filter.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(viewModel.visibleFiles) { file in
                            HStack(alignment: .center, spacing: 12) {
                                Button {
                                    viewModel.handleRowTap(file)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            SourceBadge(source: file.source)
                                            Text(file.fileName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                        }
                                        
                                        Text(file.source == .imported ? "Imported trace file" : "Recorded session trace")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 6) {
                                            Text(
                                                file.recordingDate.formatted(date: .abbreviated, time: .standard)
                                            )
                                            Text("·")
                                                .foregroundColor(.secondary)
                                            Text(file.formattedByteCount)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button {
                                    viewModel.prepareShare(for: file)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.body)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Share")
                                
                                Button(role: .destructive) {
                                    filePendingDeletion = file
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.body)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Delete")
                            }
                        }
                        .onDelete { offsets in
                            if let first = offsets.first, viewModel.visibleFiles.indices.contains(first) {
                                filePendingDeletion = viewModel.visibleFiles[first]
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.refresh()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isImportPickerPresented = true
            } label: {
                Label("Import JSON Trace", systemImage: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .fileImporter(
            isPresented: $isImportPickerPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let first = urls.first {
                    viewModel.importExternalTrace(from: first)
                }
            case .failure(let error):
                viewModel.importErrorMessage = error.localizedDescription
            }
        }
        .sheet(item: $viewModel.shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .confirmationDialog(
            "Delete trace?",
            isPresented: Binding(
                get: { filePendingDeletion != nil },
                set: { _ in }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = filePendingDeletion {
                    viewModel.delete(file: target)
                }
                filePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                filePendingDeletion = nil
            }
        } message: {
            Text(filePendingDeletion?.fileName ?? "")
        }
        .alert(
            "Import failed",
            isPresented: Binding(
                get: { viewModel.importErrorMessage != nil },
                set: { if !$0 { viewModel.importErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.importErrorMessage = nil
                }
            },
            message: {
                Text(viewModel.importErrorMessage ?? "")
            }
        )
        .alert(
            "Delete failed",
            isPresented: Binding(
                get: { viewModel.deleteErrorMessage != nil },
                set: { if !$0 { viewModel.deleteErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.deleteErrorMessage = nil
                }
            },
            message: {
                Text(viewModel.deleteErrorMessage ?? "")
            }
        )
    }
    
    private var historyFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(sourceFilterOptions, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        isSelected: viewModel.sourceFilter == filter,
                        color: chipColor(for: filter)
                    ) {
                        viewModel.selectFilter(filter)
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .padding(.vertical, 4)
    }
    
    private var sourceFilterOptions: [SessionHistorySourceFilter] {
        [.all, .thisPhone, .imported]
    }
    
    private func chipColor(for filter: SessionHistorySourceFilter) -> Color {
        switch filter {
        case .all: return .indigo
        case .thisPhone: return .blue
        case .imported: return .purple
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct SourceBadge: View {
    let source: DiagnosticTraceSource
    
    var body: some View {
        Text(source == .imported ? "IMPORT" : "SESSION")
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }
    
    private var color: Color {
        source == .imported ? .purple : .blue
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? color : color.opacity(0.14))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
