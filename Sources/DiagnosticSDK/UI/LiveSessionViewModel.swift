import Foundation
import Combine

@MainActor
final class LiveSessionViewModel: ObservableObject {
    @Published private(set) var snapshot: DiagnosticSessionSnapshot
    @Published var searchText: String = ""
    @Published var statusFilter: StatusFilter = .all
    @Published var methodFilter: MethodFilter = .all
    
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
    
    // MARK: - Private
    
    private let store: DiagnosticSessionStore
    
    private func refresh() {
        let newSnapshot = store.makeSnapshot()
        let newSignature = Signature(snapshot: newSnapshot)
        guard newSignature != lastSignature else { return }
        
        snapshot = newSnapshot
        lastSignature = newSignature
    }
}

extension LiveSessionViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case success2xx = "2xx"
        case redirect3xx = "3xx"
        case client4xx = "4xx"
        case server5xx = "5xx"
        case pending = "—"
        
        var id: String { rawValue }
        
        func matches(_ status: Int?) -> Bool {
            switch self {
            case .all: return true
            case .pending: return status == nil
            case .success2xx: return (status ?? -1) >= 200 && (status ?? -1) < 300
            case .redirect3xx: return (status ?? -1) >= 300 && (status ?? -1) < 400
            case .client4xx: return (status ?? -1) >= 400 && (status ?? -1) < 500
            case .server5xx: return (status ?? -1) >= 500 && (status ?? -1) < 600
            }
        }
    }
    
    enum MethodFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
        
        var id: String { rawValue }
        
        func matches(_ method: String) -> Bool {
            switch self {
            case .all: return true
            default: return method.uppercased() == rawValue
            }
        }
    }
    
    var filteredScreens: [DiagnosticSessionSnapshot.Screen] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        return snapshot.screens.compactMap { screen in
            let filteredInteractions = screen.interactions.filter { interaction in
                guard statusFilter.matches(interaction.status) else { return false }
                guard methodFilter.matches(interaction.method) else { return false }
                
                guard !needle.isEmpty else { return true }
                return interaction.url.lowercased().contains(needle)
                    || interaction.method.lowercased().contains(needle)
            }
            
            guard !filteredInteractions.isEmpty else { return nil }
            
            return DiagnosticSessionSnapshot.Screen(
                id: screen.id,
                name: screen.name,
                enteredAt: screen.enteredAt,
                exitedAt: screen.exitedAt,
                interactions: filteredInteractions
            )
        }
        .reversed() // most recent screen first
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
