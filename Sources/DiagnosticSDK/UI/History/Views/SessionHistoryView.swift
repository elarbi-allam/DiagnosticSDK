import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SessionHistoryView: View {
    @StateObject private var viewModel: SessionHistoryViewModel

    init() {
        let fileService = LiveSessionHistoryFileService()
        _viewModel = StateObject(wrappedValue: SessionHistoryViewModel(
            fileManager: SessionHistoryFileManager(fileService: fileService)
        ))
    }

    @ObservedObject private var replayManager = ReplayManager.shared
    @State private var isImportPickerPresented = false
    @State private var isClearAllConfirmationPresented = false
    @State private var isExportOptionsPresented = false
    @State private var exportTargetFile: DiagnosticTraceFileInfo?
    @State private var isSafeExportDialogPresented = false
    @State private var replayTargetFile: DiagnosticTraceFileInfo?
    @State private var isReplayModeDialogPresented = false
    
    var body: some View {
        contentView
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                clearAllButton
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isImportPickerPresented = true
            } label: {
                Label("Import trace", systemImage: "square.and.arrow.down")
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
            "Choose replay mode",
            isPresented: $isReplayModeDialogPresented,
            titleVisibility: .visible
        ) {
            if let target = replayTargetFile, viewModel.isReplaySelected(target) {
                Button("Stop Replay", role: .destructive) {
                    viewModel.stopReplay()
                    replayTargetFile = nil
                }
            } else {
                Button("Replay (strict)") {
                    guard let target = replayTargetFile else { return }
                    viewModel.activateReplay(for: target, queryMode: .strict)
                    replayTargetFile = nil
                }
                Button("Replay (ignore query)") {
                    guard let target = replayTargetFile else { return }
                    viewModel.activateReplay(for: target, queryMode: .ignore)
                    replayTargetFile = nil
                }
            }
            Button("Cancel", role: .cancel) {
                replayTargetFile = nil
            }
        }
        .confirmationDialog(
            "Choose export type",
            isPresented: $isExportOptionsPresented,
            titleVisibility: .visible
        ) {
            Button("Export") {
                guard let target = exportTargetFile else { return }
                viewModel.prepareShare(for: target)
                exportTargetFile = nil
            }
            Button("Safe Export") {
                isSafeExportDialogPresented = true
            }
            Button("Cancel", role: .cancel) {
                exportTargetFile = nil
            }
        }
        .background(
            ZStack {
                DiagnosticPasswordPrompt(
                    isPresented: $isSafeExportDialogPresented,
                    title: "Safe Export",
                    message: "Enter a password to encrypt the exported file.",
                    placeholder: "Password",
                    confirmTitle: "Export",
                    cancelTitle: "Cancel",
                    onConfirm: { password in
                        let normalized = password.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !normalized.isEmpty else { return }
                        guard let target = exportTargetFile else { return }
                        viewModel.prepareSafeShare(for: target, password: normalized)
                        exportTargetFile = nil
                    },
                    onCancel: {
                        exportTargetFile = nil
                    }
                )
                DiagnosticPasswordPrompt(
                    isPresented: $viewModel.isReplayPasswordPromptPresented,
                    title: "Encrypted trace",
                    message: "Enter the password to activate replay for this trace.",
                    placeholder: "Password",
                    confirmTitle: "Replay",
                    cancelTitle: "Cancel",
                    onConfirm: { password in
                        viewModel.resumeReplayActivation(with: password)
                    },
                    onCancel: {
                        viewModel.cancelReplayPasswordPrompt()
                    }
                )
            }
            .frame(width: 0, height: 0)
        )
        .alert(
            "Clear all traces?",
            isPresented: $isClearAllConfirmationPresented,
            actions: {
                Button("Delete All", role: .destructive) {
                    viewModel.clearAllFiles()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("This action will permanently remove all exported and imported trace files.")
            }
        )
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
        .alert(
            "Replay activation failed",
            isPresented: Binding(
                get: { viewModel.replayErrorMessage != nil },
                set: { if !$0 { viewModel.replayErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.replayErrorMessage = nil
                }
            },
            message: {
                Text(viewModel.replayErrorMessage ?? "")
            }
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isScanning && viewModel.files.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.files.isEmpty {
            DiagnosticEmptyStateView(
                title: "No saved traces",
                systemImage: "doc.text",
                message: "Exported sessions appear under Dx_* in Documents (for example when the app backgrounds)."
            )
        } else {
            historyList
        }
    }

    private var historyList: some View {
        List {
            if replayManager.isReplayActive, replayManager.activeTrace != nil {
                ReplayActiveBannerSection {
                    viewModel.stopReplay()
                }
            }

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
                    rowNavigation(for: file)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func rowNavigation(for file: DiagnosticTraceFileInfo) -> some View {
        NavigationLink {
            TraceInspectorView(file: file)
        } label: {
            SessionHistoryRow(
                file: file,
                isReplaySelected: viewModel.isReplaySelected(file)
            )
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                exportTargetFile = file
                isExportOptionsPresented = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.accentColor)

            Button {
                replayTargetFile = file
                isReplayModeDialogPresented = true
            } label: {
                Label("Replay", systemImage: "play.fill")
            }
            .tint(.purple)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                viewModel.delete(file: file)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private var clearAllButton: some View {
        Button("Clear All", role: .destructive) {
            isClearAllConfirmationPresented = true
        }
        .disabled(viewModel.files.isEmpty)
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

private struct ReplayLivePill: View {
    private let replayRed = Color(red: 0.86, green: 0.16, blue: 0.22)

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
            Text("REPLAY")
                .font(.caption2.weight(.black))
                .foregroundColor(.white)
                .tracking(0.2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(replayRed)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(replayRed.opacity(0.7), lineWidth: 0.8)
        )
    }
}

private struct ReplayActiveBannerSection: View {
    let onStop: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ReplayLivePill()
                Text("Replay mode is active")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Stop", action: onStop)
                    .font(.subheadline.weight(.bold))
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SessionHistoryRow: View {
    let file: DiagnosticTraceFileInfo
    let isReplaySelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SourceBadge(source: file.source)
                Text(file.displayFileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                if isReplaySelected {
                    ReplaySelectedSessionIndicator()
                }
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
}

private struct ReplaySelectedSessionIndicator: View {
    private let replayRed = Color(red: 0.86, green: 0.16, blue: 0.22)

    var body: some View {
        ZStack {
            Circle()
                .fill(replayRed.opacity(0.16))
                .frame(width: 24, height: 24)
            Circle()
                .stroke(replayRed, lineWidth: 1.1)
                .frame(width: 24, height: 24)
            Circle()
                .fill(replayRed)
                .frame(width: 8, height: 8)
        }
        .accessibilityLabel("Replay session selected")
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
