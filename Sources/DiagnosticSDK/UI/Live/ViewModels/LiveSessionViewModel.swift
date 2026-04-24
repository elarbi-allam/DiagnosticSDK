import Foundation
import Combine

struct LiveSessionShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class LiveSessionViewModel: ObservableObject {
    @Published private(set) var snapshot: DiagnosticSessionSnapshot
    @Published var searchText: String = ""
    @Published var statusFilter: TraceHTTPStatusFilter = .all
    @Published var methodFilter: TraceHTTPMethodFilter = .all
    @Published var shareItem: LiveSessionShareItem?
    @Published var exportErrorMessage: String?
    
    private var lastSignature: Signature?
    private var updateCancellable: AnyCancellable?
    
    init(store: DiagnosticSessionStore = .shared) {
        self.store = store
        self.snapshot = store.makeSnapshot()
        self.lastSignature = Signature(snapshot: self.snapshot)
        
        updateCancellable = NotificationCenter.default
            .publisher(for: .diagnosticSessionStoreDidUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }
    
    private let store: DiagnosticSessionStore
    
    private func refresh() {
        let newSnapshot = store.makeSnapshot()
        let newSignature = Signature(snapshot: newSnapshot)
        guard newSignature != lastSignature else { return }
        
        snapshot = newSnapshot
        lastSignature = newSignature
    }
    
    var filteredScreens: [DiagnosticSessionSnapshot.Screen] {
        TraceSessionListFiltering.filteredScreens(
            snapshot: snapshot,
            searchText: searchText,
            statusFilter: statusFilter,
            methodFilter: methodFilter
        )
    }
    
    var totalRequests: Int {
        snapshot.screens.reduce(into: 0) { $0 += $1.interactions.count }
    }
    
    func exportCurrentSession() {
        guard let exportedURL = store.exportSessionToDisk() else { return }
        shareItem = LiveSessionShareItem(url: exportedURL)
    }
    
    func exportCurrentSessionSafely(password: String) {
        guard let exportedURL = store.exportSessionSafelyToTemporary(password: password) else {
            exportErrorMessage = "Safe export failed. Check password and try again."
            return
        }
        shareItem = LiveSessionShareItem(url: exportedURL)
    }
    
    func clearCurrentSession() {
        store.clearCurrentSessionContent()
    }
}

private struct Signature: Equatable {
    let screensCount: Int
    let totalInteractions: Int
    let lastScreenId: String?
    let lastScreenInteractions: Int
    
    init(snapshot: DiagnosticSessionSnapshot) {
        self.screensCount = snapshot.screens.count
        self.totalInteractions = snapshot.screens.reduce(into: 0) { $0 += $1.interactions.count }
        self.lastScreenId = snapshot.screens.last?.id
        self.lastScreenInteractions = snapshot.screens.last?.interactions.count ?? 0
    }
}
