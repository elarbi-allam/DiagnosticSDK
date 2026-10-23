import Foundation

struct NetworkTimingRow: Identifiable {
    let title: String
    let value: String

    var id: String { title }
}

enum NetworkTimingRowsBuilder {
    static func makeRows(for timing: NetworkTiming?) -> [NetworkTimingRow] {
        guard let timing else { return [] }

        var rows = [NetworkTimingRow(title: "Source", value: sourceLabel(for: timing.source))]
        appendDuration(title: "Network", milliseconds: timing.networkDurationMs, to: &rows)
        appendDuration(title: "App perceived", milliseconds: timing.appPerceivedDurationMs, to: &rows)
        if let phases = timing.phases {
            appendDuration(title: "DNS lookup", milliseconds: phases.domainLookupMs, to: &rows)
            appendDuration(title: "Connection", milliseconds: phases.connectionMs, to: &rows)
            appendDuration(title: "TLS handshake", milliseconds: phases.secureConnectionMs, to: &rows)
            appendDuration(title: "Request sent", milliseconds: phases.requestSendMs, to: &rows)
            appendDuration(title: "Server wait", milliseconds: phases.serverWaitMs, to: &rows)
            appendDuration(title: "Download", milliseconds: phases.downloadMs, to: &rows)
        }
        if let networkProtocol = timing.networkProtocol {
            rows.append(NetworkTimingRow(title: "Protocol", value: networkProtocol))
        }
        if let isConnectionReused = timing.isConnectionReused {
            rows.append(NetworkTimingRow(title: "Reused connection", value: yesNoLabel(isConnectionReused)))
        }
        rows.append(NetworkTimingRow(title: "Served from cache", value: yesNoLabel(timing.isServedFromCache)))
        if timing.redirectCount > 0 {
            rows.append(NetworkTimingRow(title: "Redirects", value: "\(timing.redirectCount)"))
        }
        if let responseBytesReceived = timing.responseBytesReceived {
            rows.append(NetworkTimingRow(
                title: "Bytes received",
                value: ByteCountFormatter.string(fromByteCount: responseBytesReceived, countStyle: .file)
            ))
        }
        return rows
    }

    private static func appendDuration(title: String, milliseconds: Int?, to rows: inout [NetworkTimingRow]) {
        guard let milliseconds else { return }
        rows.append(NetworkTimingRow(title: title, value: "\(milliseconds) ms"))
    }

    private static func sourceLabel(for source: NetworkTiming.Source) -> String {
        switch source {
        case .systemMetrics:
            return "System metrics"
        case .clock:
            return "Clock"
        }
    }

    private static func yesNoLabel(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}
