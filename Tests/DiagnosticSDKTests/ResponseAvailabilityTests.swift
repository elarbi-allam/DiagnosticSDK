import XCTest
@testable import DiagnosticSDK

final class ResponseAvailabilityTests: XCTestCase {

    private let successfulResponse = ResponseDetails(
        status: 200,
        headers: nil,
        bodyBase64: nil,
        bodySizeBytes: 0,
        errorDescription: nil
    )

    private let transportFailureResponse = ResponseDetails(
        status: 0,
        headers: nil,
        bodyBase64: nil,
        bodySizeBytes: 0,
        errorDescription: "The request timed out."
    )

    func testLiveSessionWithoutResponseIsAwaiting() {
        let availability = ResponseAvailability(response: nil, captureSource: .liveSession)

        XCTAssertEqual(availability, .awaiting)
    }

    func testArchivedTraceWithoutResponseIsNeverReceived() {
        let availability = ResponseAvailability(response: nil, captureSource: .archivedTrace)

        XCTAssertEqual(availability, .neverReceived)
    }

    func testInterruptedCaptureIsNeverReceivedInEveryCaptureSource() {
        for captureSource in [TraceCaptureSource.liveSession, .archivedTrace] {
            let availability = ResponseAvailability(response: .interruptedCapture(), captureSource: captureSource)

            XCTAssertEqual(availability, .neverReceived)
        }
    }

    func testSuccessfulResponseIsReceived() {
        let availability = ResponseAvailability(response: successfulResponse, captureSource: .archivedTrace)

        XCTAssertEqual(availability, .received)
    }

    func testTransportFailureIsReceived() {
        let availability = ResponseAvailability(response: transportFailureResponse, captureSource: .liveSession)

        XCTAssertEqual(availability, .received)
    }

    func testArchivedInteractionWithoutResponseHasNoStatus() {
        let interaction = makeInteraction()

        let snapshotInteraction = DiagnosticSessionSnapshot.Interaction(
            interaction: interaction,
            isMocked: false,
            captureSource: .archivedTrace
        )

        XCTAssertNil(snapshotInteraction.status)
        XCTAssertEqual(snapshotInteraction.responseAvailability, .neverReceived)
        XCTAssertFalse(snapshotInteraction.isPending)
    }

    func testInterruptedInteractionHidesPlaceholderStatusCode() {
        var interaction = makeInteraction()
        interaction.response = .interruptedCapture()

        let snapshotInteraction = DiagnosticSessionSnapshot.Interaction(
            interaction: interaction,
            isMocked: false,
            captureSource: .liveSession
        )

        XCTAssertNil(snapshotInteraction.status)
        XCTAssertEqual(snapshotInteraction.responseAvailability, .neverReceived)
    }

    private func makeInteraction() -> NetworkInteraction {
        NetworkInteraction(
            request: RequestDetails(url: "https://example.com/resource", method: "GET", headers: [:], bodyBase64: nil, bodySizeBytes: 0)
        )
    }
}
