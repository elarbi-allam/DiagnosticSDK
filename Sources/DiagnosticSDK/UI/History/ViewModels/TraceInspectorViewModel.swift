import Foundation
import Combine

@MainActor
final class TraceInspectorViewModel: ObservableObject {
    @Published private(set) var snapshot: DiagnosticSessionSnapshot?
    @Published private(set) var interactionIndex: [String: NetworkInteraction] = [:]
    /// True until the first decode attempt finishes (initially true so the UI shows a spinner before `onAppear`).
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsPassword = false
    @Published private(set) var isViewingDecryptedSafeTrace = false
    
    @Published var searchText: String = ""
    @Published var statusFilter: TraceHTTPStatusFilter = .all
    @Published var methodFilter: TraceHTTPMethodFilter = .all
    
    private let fileURL: URL
    private var encryptedWrapper: SecureTraceWrapper?
    private var hasLoadedInitialData = false
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    func loadIfNeeded() {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true
        load()
    }
    
    func load() {
        isLoading = true
        errorMessage = nil
        needsPassword = false
        isViewingDecryptedSafeTrace = false
        encryptedWrapper = nil
        snapshot = nil
        interactionIndex = [:]
        
        let url = fileURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<TraceSessionFileLoader.DecodedTraceContent, Error> = Result {
                try TraceSessionFileLoader.decodeTraceContent(from: url)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let content):
                    switch content {
                    case .plain(let trace):
                        self.apply(trace: trace)
                    case .encrypted(let wrapper):
                        self.encryptedWrapper = wrapper
                        self.needsPassword = true
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func unlockEncryptedTrace(password: String) {
        guard let wrapper = encryptedWrapper else { return }
        needsPassword = false
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<SessionTrace, Error> = Result {
                try TraceSessionFileLoader.decryptSession(wrapper: wrapper, password: password)
            }
            
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let trace):
                    self.needsPassword = false
                    self.isViewingDecryptedSafeTrace = true
                    self.apply(trace: trace)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.needsPassword = true
                }
            }
        }
    }
    
    func cancelUnlock() {
        needsPassword = false
        if snapshot == nil {
            errorMessage = "Encrypted trace was not unlocked."
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
    
    private func apply(trace: SessionTrace) {
        snapshot = DiagnosticSessionSnapshot(sessionTrace: trace)
        interactionIndex = TraceSessionFileLoader.interactionIndex(from: trace)
    }
}
