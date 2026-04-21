import Foundation

/// Shared HTTP status bucket filter for live and recorded trace lists.
enum TraceHTTPStatusFilter: String, CaseIterable, Identifiable {
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

/// Shared HTTP method filter for live and recorded trace lists.
enum TraceHTTPMethodFilter: String, CaseIterable, Identifiable {
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

enum TraceSessionListFiltering {
    /// Applies search + filters; returns screens with newest-first section order (matches live session).
    static func filteredScreens(
        snapshot: DiagnosticSessionSnapshot,
        searchText: String,
        statusFilter: TraceHTTPStatusFilter,
        methodFilter: TraceHTTPMethodFilter
    ) -> [DiagnosticSessionSnapshot.Screen] {
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
        .reversed()
    }
}
