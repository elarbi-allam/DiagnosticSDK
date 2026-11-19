import XCTest
@testable import DiagnosticSDK

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class AsyncAwaitCaptureTests: XCTestCase {

    private static let responseBody = Data(#"{"access_token":"token"}"#.utf8)

    private var recorder: ResponseBodyRecorderSpy!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        DiagnosticSDKNetworkHooks.installHooks()
        recorder = ResponseBodyRecorderSpy()
        DiagnosticSDKNetworkHooks.eventObserver = NetworkTaskObserver(recorder: recorder)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JSONBackendURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        DiagnosticSDKNetworkHooks.eventObserver = nil
        session = nil
        recorder = nil
        super.tearDown()
    }

    func testDataForRequestCapturesTheResponseBody() async throws {
        _ = try await session.data(for: URLRequest(url: URL(string: "https://async.test/data")!))

        let capture = await recorder.waitForFirstCapture()
        XCTAssertEqual(capture?.responseBody, Self.responseBody)
    }

    func testUploadForRequestCapturesTheRequestAndResponseBodies() async throws {
        var request = URLRequest(url: URL(string: "https://async.test/upload")!)
        request.httpMethod = "POST"
        let uploadedBody = Data(#"{"source":"async"}"#.utf8)

        _ = try await session.upload(for: request, from: uploadedBody)

        let capture = await recorder.waitForFirstCapture()
        XCTAssertEqual(capture?.requestBody, uploadedBody)
        XCTAssertEqual(capture?.responseBody, Self.responseBody)
    }

    func testDataForRequestWithTaskDelegateCapturesTheResponseBody() async throws {
        _ = try await session.data(for: URLRequest(url: URL(string: "https://async.test/delegate")!), delegate: EmptyTaskDelegate())

        let capture = await recorder.waitForFirstCapture()
        XCTAssertEqual(capture?.responseBody, Self.responseBody)
    }
}

private final class ResponseBodyRecorderSpy: NetworkTrafficRecording {

    struct Capture {
        let requestBody: Data?
        let responseBody: Data?
    }

    private let lock = NSLock()
    private var captures: [Capture] = []

    func waitForFirstCapture() async -> Capture? {
        for _ in 0..<50 {
            lock.lock()
            let firstCapture = captures.first
            lock.unlock()
            if let firstCapture { return firstCapture }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
    }

    func recordStart(of pendingCapture: PendingNetworkCapture) {}

    func record(
        _ completedCapture: CompletedNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        receivedResponseByteCount: Int,
        error: Error?,
        isMocked: Bool
    ) {
        lock.lock()
        captures.append(Capture(requestBody: completedCapture.pendingCapture.request.httpBody, responseBody: responseBody))
        lock.unlock()
    }

    func recordLateMetrics(_ metrics: TaskMetricsSnapshot, for timingContext: FinishedCaptureTimingContext) {}

    func interruptPendingCaptures() {}
}

private final class JSONBackendURLProtocol: URLProtocol {

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"access_token":"token"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class EmptyTaskDelegate: NSObject, URLSessionTaskDelegate {}
