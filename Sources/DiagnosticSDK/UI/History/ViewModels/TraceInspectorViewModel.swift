import Foundation
import Combine

@MainActor
final class TraceInspectorViewModel: ObservableObject {
    @Published private(set) var snapshot: DiagnosticSessionSnapshot?
    @Published private(set) var interactionIndex: [String: NetworkInteraction] = [:]
    /// True until the first decode attempt finishes (initially true so the UI shows a spinner before `onAppear`).
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    
    @Published var searchText: String = ""
    @Published var statusFilter: TraceHTTPStatusFilter = .all
    @Published var methodFilter: TraceHTTPMethodFilter = .all
    
    private let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    func load() {
        isLoading = true
        errorMessage = nil
        snapshot = nil
        interactionIndex = [:]
        
        let url = fileURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<(DiagnosticSessionSnapshot, [String: NetworkInteraction]), Error> = Result {
                let trace = try TraceSessionFileLoader.decodeSession(from: url)
                let snapshot = DiagnosticSessionSnapshot(sessionTrace: trace)
                let index = TraceSessionFileLoader.interactionIndex(from: trace)
                return (snapshot, index)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let pair):
                    self.snapshot = pair.0
                    self.interactionIndex = pair.1
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    var filteredScreens: [DiagnosticSessionSnapshot.Screen] {
        guard let snapshot else { return [] }
        return TraceSessionListFiltering.filteredScreens(
            snapshot: snapshot,
            searchText: searchText,
            statusFilter: statusFilter,
            methodFilter: methodFilter
        )
    }
    
    var totalRequests: Int {
        guard let snapshot else { return 0 }
        return snapshot.screens.reduce(into: 0) { $0 += $1.interactions.count }
    }
    
    func interaction(for id: String) -> NetworkInteraction? {
        interactionIndex[id]
    }
}
