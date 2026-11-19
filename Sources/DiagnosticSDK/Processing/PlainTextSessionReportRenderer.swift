import Foundation

protocol SessionReportRendering {
    var fileExtension: String { get }
    func renderDocumentStart(_ summary: SessionReportSummary) -> String
    func renderScreenStart(_ screen: SessionReportScreenHeader) -> String
    func renderEntry(_ entry: SessionReportEntry) -> String
    func renderScreenEnd() -> String
    func renderDocumentEnd() -> String
}

struct PlainTextSessionReportRenderer: SessionReportRendering {

    private static let lineWidth = 80
    private static let sectionIndentation = "  "
    private static let contentIndentation = "      "

    let fileExtension = "txt"

    func renderDocumentStart(_ summary: SessionReportSummary) -> String {
        let doubleRule = String(repeating: "=", count: Self.lineWidth)
        var lines = [
            doubleRule,
            "DIAGNOSTIC SESSION REPORT",
            doubleRule,
            labeledLine("Session", summary.sessionId),
            labeledLine("Started", summary.startedAtText),
            labeledLine("Device", summary.applicationText),
            labeledLine("Requests", "\(summary.requestCount) total · \(summary.failedRequestCount) failed · \(SessionReportCountFormatting.text(count: summary.screens.count, noun: "screen"))"),
            doubleRule,
            "",
            "SCREENS"
        ]
        lines += summary.screens.map { screen in
            "  \(screen.number). \(screen.name) · \(screen.enteredAtText) · \(screen.requestCountText)"
        }
        return lines.joined(separator: "\n") + "\n\n"
    }

    func renderScreenStart(_ screen: SessionReportScreenHeader) -> String {
        let title = "SCREEN \(screen.number) · \(screen.name) · \(screen.enteredAtText)"
        return "\n\(String(repeating: "#", count: Self.lineWidth))\n\(title)\n\(String(repeating: "#", count: Self.lineWidth))\n"
    }

    func renderEntry(_ entry: SessionReportEntry) -> String {
        var lines = [
            "",
            "[#\(entry.number)] \(entry.method) \(entry.url)",
            "      Status \(entry.status.text) · \(entry.durationText) · started \(entry.startedAtText)",
            String(repeating: "-", count: Self.lineWidth)
        ]
        lines += messageLines(title: "REQUEST", message: entry.request)
        if let response = entry.response {
            lines += messageLines(title: "RESPONSE", message: response)
        } else {
            lines += ["", Self.sectionIndentation + "RESPONSE", Self.contentIndentation + "No response received."]
        }
        if let errorDescription = entry.errorDescription {
            lines += ["", Self.sectionIndentation + "ERROR", Self.contentIndentation + errorDescription]
        }
        if !entry.timingRows.isEmpty {
            lines += ["", Self.sectionIndentation + "TIMING"]
            lines += entry.timingRows.map { Self.contentIndentation + "\($0.title): \($0.value)" }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func renderScreenEnd() -> String {
        ""
    }

    func renderDocumentEnd() -> String {
        "\n\(String(repeating: "=", count: Self.lineWidth))\nEND OF REPORT\n"
    }

    private func labeledLine(_ label: String, _ value: String) -> String {
        label.padding(toLength: 10, withPad: " ", startingAt: 0) + value
    }

    private func messageLines(title: String, message: SessionReportMessage) -> [String] {
        var lines = ["", Self.sectionIndentation + "\(title) HEADERS"]
        if message.headers.isEmpty {
            lines.append(Self.contentIndentation + "None")
        } else {
            lines += message.headers.map { Self.contentIndentation + "\($0.name): \($0.value)" }
        }
        lines += ["", Self.sectionIndentation + "\(title) BODY · \(message.bodyTitle)"]
        if let bodyNotice = message.bodyNotice {
            lines.append(Self.contentIndentation + "! \(bodyNotice)")
        }
        lines += indentedLines(of: message.body)
        return lines
    }

    private func indentedLines(of body: SessionReportBody) -> [String] {
        switch body {
        case .json(let text), .text(let text):
            return text.components(separatedBy: .newlines).map { Self.contentIndentation + $0 }
        case .placeholder(let message):
            return [Self.contentIndentation + message]
        }
    }
}
