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
    @Published private(set) var isUnlocking = false
    @Published private(set) var unlockErrorMessage: String?
    @Published private(set) var passwordPromptRequestID = 0
    
    @Published var searchText: String = ""
    @Published var statusFilter: TraceHTTPStatusFilter = .all
    @Published var methodFilter: TraceHTTPMethodFilter = .all
    
    private let fileURL: URL
    private var encryptedWrapper: SecureTraceWrapper?
    private var hasLoadedInitialData = false
    private var unlockAttemptCounter = 0
    
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
        isUnlocking = false
        unlockErrorMessage = nil
        passwordPromptRequestID = 0
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
                        self.unlockErrorMessage = nil
                        self.requestPasswordPrompt()
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func unlockEncryptedTrace(password: String) {
        guard let wrapper = encryptedWrapper, !isUnlocking else { return }
        unlockAttemptCounter += 1
        let attemptID = unlockAttemptCounter
        
        needsPassword = false
        isLoading = true
        isUnlocking = true
        errorMessage = nil
        unlockErrorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<SessionTrace, Error> = Result {
                try TraceSessionFileLoader.decryptSession(wrapper: wrapper, password: password)
            }
            
            DispatchQueue.main.async {
                guard let self else { return }
                guard attemptID == self.unlockAttemptCounter else { return }
                
                self.isLoading = false
                self.isUnlocking = false
                switch result {
                case .success(let trace):
                    self.needsPassword = false
                    self.isViewingDecryptedSafeTrace = true
                    self.apply(trace: trace)
                case .failure(let error):
                    if let loaderError = error as? TraceSessionFileLoaderError {
                        switch loaderError {
                        case .wrongPasswordOrCorruptedFile, .invalidEncryptedFile:
                            self.unlockErrorMessage = loaderError.localizedDescription
                            self.requestPasswordPrompt()
                        case .fileReadFailed, .unsupportedFormat, .passwordRequired:
                            self.errorMessage = loaderError.localizedDescription
                            self.needsPassword = false
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                        self.needsPassword = false
                    }
                }
            }
        }
    }
    
    func cancelUnlock() {
        unlockErrorMessage = nil
        needsPassword = false
        if snapshot == nil {
            errorMessage = "Encrypted trace was not unlocked."
        }
    }

    var passwordPromptMessage: String {
        let base = "Enter the password used during Safe Export to open this trace."
        guard let unlockErrorMessage else { return base }
        return "\(base)\n\n\(unlockErrorMessage)"
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
    
    private func requestPasswordPrompt() {
        needsPassword = true
        passwordPromptRequestID += 1
    }
}
