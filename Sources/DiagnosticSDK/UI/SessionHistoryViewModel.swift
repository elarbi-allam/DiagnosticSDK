import Combine
import Foundation

struct SessionHistoryShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

enum SessionHistorySourceFilter: Hashable {
    case all
    case thisPhone
    case imported
    
    var title: String {
        switch self {
        case .all: return "All"
        case .thisPhone: return "This Phone"
        case .imported: return "Imported"
        }
    }
}

final class SessionHistoryViewModel: ObservableObject {
    @Published private(set) var files: [DiagnosticTraceFileInfo] = []
    @Published private(set) var isScanning = false
    @Published var importErrorMessage: String?
    @Published var deleteErrorMessage: String?
    @Published var shareItem: SessionHistoryShareItem?
    @Published var sourceFilter: SessionHistorySourceFilter = .all
    
    var visibleFiles: [DiagnosticTraceFileInfo] {
        switch sourceFilter {
        case .all:
            return files
        case .thisPhone:
            return files.filter { $0.source == .session }
        case .imported:
            return files.filter { $0.source == .imported }
        }
    }
    
    func refresh() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try SessionHistoryFileService.listTraceFiles() }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isScanning = false
                switch result {
                case .success(let list):
                    self.files = list
                case .failure:
                    self.files = []
                }
            }
        }
    }
    
    func delete(at offsets: IndexSet) {
        let filesToDelete = offsets.compactMap { index -> DiagnosticTraceFileInfo? in
            guard visibleFiles.indices.contains(index) else { return nil }
            return visibleFiles[index]
        }
        guard !filesToDelete.isEmpty else { return }
        
        let ids = Set(filesToDelete.map(\.id))
        files.removeAll { ids.contains($0.id) }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for file in filesToDelete {
                do {
                    print("[DiagnosticSDK] Delete requested for: \(file.fileName) at \(file.url.path)")
                    let report = try SessionHistoryFileService.deleteFile(at: file.url)
                    if report.deleted {
                        print("✅ [DiagnosticSDK] Deleted trace JSON: \(file.fileName)")
                        print("[DiagnosticSDK] \(report.debugMessage)")
                    } else {
                        print("[DiagnosticSDK] Delete skipped (file not found): \(file.fileName)")
                        print("[DiagnosticSDK] \(report.debugMessage)")
                        DispatchQueue.main.async {
                            self?.deleteErrorMessage = "File not found on disk: \(file.fileName)"
                        }
                    }
                } catch {
                    print("❌ [DiagnosticSDK] Failed to delete trace JSON \(file.fileName): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.deleteErrorMessage = error.localizedDescription
                    }
                }
            }
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }
    
    func delete(file: DiagnosticTraceFileInfo) {
        files.removeAll { $0.id == file.id }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                print("[DiagnosticSDK] Delete requested for: \(file.fileName) at \(file.url.path)")
                let report = try SessionHistoryFileService.deleteFile(at: file.url)
                if report.deleted {
                    print("✅ [DiagnosticSDK] Deleted trace JSON: \(file.fileName)")
                    print("[DiagnosticSDK] \(report.debugMessage)")
                } else {
                    print("[DiagnosticSDK] Delete skipped (file not found): \(file.fileName)")
                    print("[DiagnosticSDK] \(report.debugMessage)")
                    DispatchQueue.main.async {
                        self?.deleteErrorMessage = "File not found on disk: \(file.fileName)"
                    }
                }
            } catch {
                print("❌ [DiagnosticSDK] Failed to delete trace JSON \(file.fileName): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.deleteErrorMessage = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }
    
    func importExternalTrace(from sourceURL: URL) {
        let startedAccess = sourceURL.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try SessionHistoryFileService.copyImportedJSONToDocuments(from: sourceURL)
            }
            DispatchQueue.main.async {
                if startedAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
                guard let self else { return }
                switch result {
                case .success(let importedURL):
                    print("✅ [DiagnosticSDK] Imported trace JSON: \(importedURL.lastPathComponent)")
                    self.importErrorMessage = nil
                    self.refresh()
                case .failure(let error):
                    self.importErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func selectFilter(_ filter: SessionHistorySourceFilter) {
        sourceFilter = filter
    }
    
    func handleRowTap(_ file: DiagnosticTraceFileInfo) {
        print(file.fileName)
    }
    
    func prepareShare(for file: DiagnosticTraceFileInfo) {
        shareItem = SessionHistoryShareItem(url: file.url)
    }
}
