import Foundation

enum SessionReportFormat {
    case plainText
    case html

    var renderer: SessionReportRendering {
        switch self {
        case .plainText: return PlainTextSessionReportRenderer()
        case .html: return HTMLSessionReportRenderer()
        }
    }
}

enum SessionReportWriter {

    static func writeReport(of session: SessionTrace, format: SessionReportFormat) throws -> URL {
        let renderer = format.renderer
        let reportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(reportFileName(for: session, fileExtension: renderer.fileExtension))
        FileManager.default.createFile(atPath: reportURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: reportURL)
        defer { try? fileHandle.close() }

        try write(renderer.renderDocumentStart(SessionReportSummary(session: session)), to: fileHandle)
        var entryNumber = 0
        for (screenIndex, screen) in session.screens.enumerated() {
            try write(renderer.renderScreenStart(SessionReportScreenHeader(number: screenIndex + 1, screen: screen)), to: fileHandle)
            for interaction in screen.networkInteractions {
                entryNumber += 1
                try autoreleasepool {
                    try write(renderer.renderEntry(SessionReportEntry(number: entryNumber, interaction: interaction)), to: fileHandle)
                }
            }
            try write(renderer.renderScreenEnd(), to: fileHandle)
        }
        try write(renderer.renderDocumentEnd(), to: fileHandle)
        print("✅ [DiagnosticSDK] Readable report created at: \(reportURL.path)")
        return reportURL
    }

    private static func write(_ text: String, to fileHandle: FileHandle) throws {
        try fileHandle.write(contentsOf: Data(text.utf8))
    }

    private static func reportFileName(for session: SessionTrace, fileExtension: String) -> String {
        let shortIdentifier = session.sessionId.filter(\.isHexDigit).prefix(7).uppercased()
        return "Dx_\(shortIdentifier.isEmpty ? "0000000" : shortIdentifier)_Report.\(fileExtension)"
    }
}
