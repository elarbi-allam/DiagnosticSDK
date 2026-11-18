import XCTest
@testable import DiagnosticSDK

final class SessionStoreBodyBudgetTests: XCTestCase {

    func testOldestBodiesAreDiscardedWhenTheBudgetIsExceeded() {
        let store = DiagnosticSessionStore(retainedBodyByteBudget: 12)

        store.save(event: makeEvent(captureId: "first", responseBody: "12345678"))
        store.save(event: makeEvent(captureId: "second", responseBody: "abcdefgh"))

        let firstResponse = store.getInteraction(byId: "first")?.response
        let secondResponse = store.getInteraction(byId: "second")?.response
        XCTAssertNil(firstResponse?.bodyBase64)
        XCTAssertEqual(firstResponse?.bodyOmission, .memoryBudget)
        XCTAssertEqual(firstResponse?.bodySizeBytes, 8)
        XCTAssertEqual(secondResponse?.bodyBase64, "abcdefgh")
        XCTAssertNil(secondResponse?.bodyOmission)
    }

    func testBodiesWithinTheBudgetAreKept() {
        let store = DiagnosticSessionStore(retainedBodyByteBudget: 64)

        store.save(event: makeEvent(captureId: "first", responseBody: "12345678"))
        store.save(event: makeEvent(captureId: "second", responseBody: "abcdefgh"))

        XCTAssertEqual(store.getInteraction(byId: "first")?.response?.bodyBase64, "12345678")
        XCTAssertEqual(store.getInteraction(byId: "second")?.response?.bodyBase64, "abcdefgh")
    }

    private func makeEvent(captureId: String, responseBody: String) -> NetworkEvent {
        NetworkEvent(
            request: RequestModel(url: "https://example.com/\(captureId)", method: "GET", headers: [:], body: nil),
            response: ResponseModel(
                statusCode: 200,
                headers: ["Content-Type": "text/plain"],
                bodyBase64: responseBody,
                bodySizeBytes: responseBody.utf8.count,
                errorDescription: nil,
                bodyEncoding: .text
            ),
            timestamp: Date(),
            captureId: captureId
        )
    }
}
