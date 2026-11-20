import XCTest
@testable import DiagnosticSDK

final class ReplayResponseFactoryTests: XCTestCase {

    private let request = URLRequest(url: URL(string: "https://example.com/resource")!)

    func testTransportHeadersAreRecomputedForTheDecodedBody() {
        let interaction = makeInteraction(response: ResponseDetails(
            status: 200,
            headers: ["Content-Type": "application/json", "Content-Encoding": "gzip", "Content-Length": "12", "Set-Cookie": "id=1"],
            bodyBase64: #"{"compressed":true}"#,
            bodySizeBytes: 19,
            errorDescription: nil,
            bodyEncoding: .text
        ))

        let payload = ReplayResponseFactory().makePayload(for: request, from: interaction)

        XCTAssertEqual(payload?.bodyData, Data(#"{"compressed":true}"#.utf8))
        XCTAssertNil(payload?.response.value(forHTTPHeaderField: "Content-Encoding"))
        XCTAssertEqual(payload?.response.value(forHTTPHeaderField: "Content-Length"), "19")
        XCTAssertEqual(payload?.response.value(forHTTPHeaderField: "Set-Cookie"), "id=1")
        XCTAssertEqual(payload?.response.mimeType, "application/json")
    }

    func testTextBodyIsReplayedWithItsDeclaredCharset() {
        let contentType = "text/html; charset=ISO-8859-1"
        let interaction = makeInteraction(response: ResponseDetails(
            status: 200,
            headers: ["Content-Type": contentType],
            bodyBase64: "café",
            bodySizeBytes: 4,
            errorDescription: nil,
            bodyEncoding: .text
        ))

        let payload = ReplayResponseFactory().makePayload(for: request, from: interaction)

        XCTAssertEqual(payload?.bodyData, "café".data(using: .isoLatin1))
        XCTAssertEqual(payload?.response.textEncodingName?.lowercased(), "iso-8859-1")
    }

    func testOnlyCompleteRecordedResponsesAreReplayable() {
        XCTAssertTrue(ReplayResponseFactory.canReplay(makeInteraction(response: textResponse())))
        XCTAssertFalse(ReplayResponseFactory.canReplay(makeInteraction(response: textResponse(isBodyTruncated: true))))
        XCTAssertFalse(ReplayResponseFactory.canReplay(makeInteraction(response: ResponseDetails(
            status: 200,
            headers: ["Content-Type": "application/pdf"],
            bodyBase64: nil,
            bodySizeBytes: 4096,
            errorDescription: nil,
            bodyOmission: .binaryContent
        ))))
        XCTAssertFalse(ReplayResponseFactory.canReplay(makeInteraction(response: ResponseDetails(
            status: 0,
            headers: nil,
            bodyBase64: nil,
            bodySizeBytes: 0,
            errorDescription: "The request timed out."
        ))))
    }

    func testLegacyNonJSONResponsesStayExcludedFromReplay() {
        let legacyPlaceholderResponse = ResponseDetails(
            status: 200,
            headers: ["Content-Type": "text/html"],
            bodyBase64: "can't save this type of content: text/html",
            bodySizeBytes: 512,
            errorDescription: nil
        )
        let legacyJSONResponse = ResponseDetails(
            status: 200,
            headers: ["Content-Type": "application/json"],
            bodyBase64: Data(#"{"a":1}"#.utf8).base64EncodedString(),
            bodySizeBytes: 7,
            errorDescription: nil
        )

        XCTAssertFalse(ReplayResponseFactory.canReplay(makeInteraction(response: legacyPlaceholderResponse)))
        XCTAssertTrue(ReplayResponseFactory.canReplay(makeInteraction(response: legacyJSONResponse)))
    }

    private func textResponse(isBodyTruncated: Bool? = nil) -> ResponseDetails {
        ResponseDetails(
            status: 200,
            headers: ["Content-Type": "text/plain"],
            bodyBase64: "hello",
            bodySizeBytes: 5,
            errorDescription: nil,
            bodyEncoding: .text,
            isBodyTruncated: isBodyTruncated
        )
    }

    private func makeInteraction(response: ResponseDetails) -> NetworkInteraction {
        var interaction = NetworkInteraction(
            request: RequestDetails(url: "https://example.com/resource", method: "GET", headers: nil, bodyBase64: nil, bodySizeBytes: 0)
        )
        interaction.response = response
        return interaction
    }
}
