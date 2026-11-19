import XCTest
@testable import DiagnosticSDK

final class SessionReportWriterTests: XCTestCase {

    func testPlainTextReportListsRequestsWithFormattedBodies() throws {
        let reportURL = try SessionReportWriter.writeReport(of: makeSession(), format: .plainText)
        defer { try? FileManager.default.removeItem(at: reportURL) }

        let report = try String(contentsOf: reportURL, encoding: .utf8)

        XCTAssertEqual(reportURL.pathExtension, "txt")
        XCTAssertTrue(report.contains("2 total · 1 failed · 1 screen"))
        XCTAssertTrue(report.contains("[#1] POST https://example.com/token"))
        XCTAssertTrue(report.contains("username = ada@example.com"))
        XCTAssertTrue(report.contains("\"name\" : \"Ada\""))
        XCTAssertTrue(report.contains("Status 500"))
    }

    func testHTMLReportEscapesContentAndHighlightsJSON() throws {
        let reportURL = try SessionReportWriter.writeReport(of: makeSession(), format: .html)
        defer { try? FileManager.default.removeItem(at: reportURL) }

        let report = try String(contentsOf: reportURL, encoding: .utf8)

        XCTAssertEqual(reportURL.pathExtension, "html")
        XCTAssertTrue(report.hasPrefix("<!doctype html>"))
        XCTAssertTrue(report.contains("&lt;b&gt;bold&lt;/b&gt;"))
        XCTAssertFalse(report.contains("<b>bold</b>"))
        XCTAssertTrue(report.contains("<span class=\"json-key\">&quot;name&quot;</span>"))
        XCTAssertTrue(report.contains("status-server-error"))
        XCTAssertTrue(report.hasSuffix("</html>\n"))
    }

    private func makeSession() -> SessionTrace {
        var session = SessionTrace()
        let screen = ScreenNode(name: "LoginViewController")
        var tokenRequest = NetworkInteraction(request: RequestDetails(
            url: "https://example.com/token",
            method: "POST",
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            bodyBase64: "username=ada%40example.com",
            bodySizeBytes: 26,
            bodyEncoding: .text
        ))
        tokenRequest.response = ResponseDetails(
            status: 200,
            headers: ["Content-Type": "application/json"],
            bodyBase64: #"{"name":"Ada"}"#,
            bodySizeBytes: 14,
            errorDescription: nil,
            bodyEncoding: .text
        )
        var failingRequest = NetworkInteraction(request: RequestDetails(
            url: "https://example.com/page",
            method: "GET",
            headers: nil,
            bodyBase64: nil,
            bodySizeBytes: 0
        ))
        failingRequest.response = ResponseDetails(
            status: 500,
            headers: ["Content-Type": "text/html"],
            bodyBase64: "<b>bold</b>",
            bodySizeBytes: 11,
            errorDescription: nil,
            bodyEncoding: .text
        )
        screen.networkInteractions = [tokenRequest, failingRequest]
        session.screens = [screen]
        return session
    }
}
