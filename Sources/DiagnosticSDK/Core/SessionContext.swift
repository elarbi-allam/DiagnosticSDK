import Foundation

/// Tracks the active capture session across app lifecycle transitions.
final class SessionContext {
    static let shared = SessionContext()

    private let queue = DispatchQueue(label: "diagnosticsdk.session.context")
    private var currentSessionIdValue = UUID().uuidString
    private var currentSessionStartedAtValue = Date()

    private init() {}

    var currentSessionId: String {
        queue.sync { currentSessionIdValue }
    }

    var currentSessionStartedAt: Date {
        queue.sync { currentSessionStartedAtValue }
    }

    func startNewSession() {
        queue.sync {
            currentSessionIdValue = UUID().uuidString
            currentSessionStartedAtValue = Date()
        }
    }
}
