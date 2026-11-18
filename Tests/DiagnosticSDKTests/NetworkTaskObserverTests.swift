import XCTest
@testable import DiagnosticSDK

final class NetworkTaskObserverTests: XCTestCase {

    private var session: URLSession!
    private var recorder: NetworkTrafficRecorderSpy!
    private var observer: NetworkTaskObserver!

    override func setUp() {
        super.setUp()
        session = URLSession(configuration: .ephemeral)
        recorder = NetworkTrafficRecorderSpy()
        observer = NetworkTaskObserver(recorder: recorder)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        observer = nil
        recorder = nil
        super.tearDown()
    }

    func testSuspendedTaskStartsCapture() {
        let task = session.dataTask(with: URL(string: "https://example.invalid/resource")!)

        observer.networkTaskWillResume(task)

        XCTAssertEqual(recorder.startedCaptureCount, 1)
    }

    func testCancelledTaskIsNotCapturedWhenResumedAgain() {
        let task = session.dataTask(with: URL(string: "https://example.invalid/resource")!)
        task.cancel()

        observer.networkTaskWillResume(task)

        XCTAssertEqual(recorder.startedCaptureCount, 0)
    }

    func testResumingTheSameTaskTwiceStartsASingleCapture() {
        let task = session.dataTask(with: URL(string: "https://example.invalid/resource")!)

        observer.networkTaskWillResume(task)
        observer.networkTaskWillResume(task)

        XCTAssertEqual(recorder.startedCaptureCount, 1)
    }
}

private final class NetworkTrafficRecorderSpy: NetworkTrafficRecording {

    private(set) var startedCaptureCount = 0

    func recordStart(of pendingCapture: PendingNetworkCapture) {
        startedCaptureCount += 1
    }

    func record(
        _ completedCapture: CompletedNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        error: Error?,
        isMocked: Bool
    ) {}

    func recordLateMetrics(_ metrics: TaskMetricsSnapshot, for timingContext: FinishedCaptureTimingContext) {}

    func interruptPendingCaptures() {}
}
