import XCTest
@testable import DiagnosticSDK

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class URLProtocolRelayTests: XCTestCase {

    private static let requestBody = Data("grant_type=password&username=ada".utf8)

    private var recorder: CompletedCaptureRecorderSpy!

    override func setUp() {
        super.setUp()
        DiagnosticSDKNetworkHooks.installHooks()
        recorder = CompletedCaptureRecorderSpy()
        DiagnosticSDKNetworkHooks.eventObserver = NetworkTaskObserver(recorder: recorder)
    }

    override func tearDown() {
        DiagnosticSDKNetworkHooks.eventObserver = nil
        recorder = nil
        super.tearDown()
    }

    func testSynchronousRelayIsMergedIntoTheApplicationRequest() {
        let session = makeSession(protocolClasses: [SynchronousRelayURLProtocol.self])
        defer { session.invalidateAndCancel() }

        sendFormRequests(count: 1, through: session)

        let captures = recorder.completedCapturesAfterSettling(expectedCount: 1, testCase: self)
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(recorder.startedCaptureCount, 1)
        XCTAssertEqual(captures.first?.pendingCapture.request.httpBody, Self.requestBody)
        XCTAssertTrue(captures.first?.deliveringURLProtocolName?.contains("SynchronousRelayURLProtocol") == true)
        XCTAssertTrue(captures.first?.metrics != nil || recorder.lateMetricsCount > 0)
    }

    func testConcurrentIdenticalRequestsThroughARelayAreNeverMerged() {
        let session = makeSession(protocolClasses: [SynchronousRelayURLProtocol.self])
        defer { session.invalidateAndCancel() }

        sendFormRequests(count: 2, through: session)

        let captures = recorder.completedCapturesAfterSettling(expectedCount: 2, testCase: self)
        XCTAssertEqual(captures.count, 2)
        XCTAssertTrue(captures.allSatisfy { $0.pendingCapture.request.httpBody == Self.requestBody })
    }

    func testAsynchronousRelayIsKeptVisibleInsteadOfBeingGuessed() {
        let session = makeSession(protocolClasses: [AsynchronousRelayURLProtocol.self])
        defer { session.invalidateAndCancel() }

        sendFormRequests(count: 1, through: session)

        let captures = recorder.completedCapturesAfterSettling(expectedCount: 2, testCase: self)
        XCTAssertEqual(captures.count, 2)
    }

    func testStubbedResponseIsAttributedToItsURLProtocolWithoutFakeCacheMetrics() {
        let session = makeSession(protocolClasses: [CannedBackendURLProtocol.self])
        defer { session.invalidateAndCancel() }

        sendFormRequests(count: 1, through: session)

        let captures = recorder.completedCapturesAfterSettling(expectedCount: 1, testCase: self)
        XCTAssertEqual(captures.count, 1)
        XCTAssertTrue(captures.first?.deliveringURLProtocolName?.contains("CannedBackendURLProtocol") == true)
        XCTAssertNil(captures.first?.metrics)
        XCTAssertEqual(recorder.lateMetricsCount, 0)
    }

    func testRequestWithoutURLProtocolIsCapturedOnceWithoutAttribution() {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let completion = expectation(description: "request completion")
        session.dataTask(with: URL(string: "https://127.0.0.1:1/unreachable")!) { _, _, _ in
            completion.fulfill()
        }.resume()
        wait(for: [completion], timeout: 10)

        let captures = recorder.completedCapturesAfterSettling(expectedCount: 1, testCase: self)
        XCTAssertEqual(captures.count, 1)
        XCTAssertNil(captures.first?.deliveringURLProtocolName)
    }

    private func makeSession(protocolClasses: [AnyClass]) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = protocolClasses
        return URLSession(configuration: configuration)
    }

    private func sendFormRequests(count: Int, through session: URLSession) {
        let completions = (0..<count).map { expectation(description: "request \($0) completion") }
        for completion in completions {
            var request = URLRequest(url: URL(string: "https://relay.test/token")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.requestBody
            session.dataTask(with: request) { _, _, _ in
                completion.fulfill()
            }.resume()
        }
        wait(for: completions, timeout: 10)
    }
}

private final class CompletedCaptureRecorderSpy: NetworkTrafficRecording {

    private let lock = NSLock()
    private var completedCaptures: [CompletedNetworkCapture] = []
    private var startedCaptures = 0
    private var lateMetrics = 0

    var startedCaptureCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return startedCaptures
    }

    var lateMetricsCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return lateMetrics
    }

    func completedCapturesAfterSettling(expectedCount: Int, testCase: XCTestCase) -> [CompletedNetworkCapture] {
        let settled = testCase.expectation(description: "captures settled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { settled.fulfill() }
        testCase.wait(for: [settled], timeout: 5)
        lock.lock()
        defer { lock.unlock() }
        return completedCaptures
    }

    func recordStart(of pendingCapture: PendingNetworkCapture) {
        lock.lock()
        startedCaptures += 1
        lock.unlock()
    }

    func record(
        _ completedCapture: CompletedNetworkCapture,
        response: URLResponse?,
        responseBody: Data?,
        receivedResponseByteCount: Int,
        error: Error?,
        isMocked: Bool
    ) {
        lock.lock()
        completedCaptures.append(completedCapture)
        lock.unlock()
    }

    func recordLateMetrics(_ metrics: TaskMetricsSnapshot, for timingContext: FinishedCaptureTimingContext) {
        lock.lock()
        lateMetrics += 1
        lock.unlock()
    }

    func interruptPendingCaptures() {}
}

private class CannedBackendURLProtocol: URLProtocol {

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

private class SynchronousRelayURLProtocol: URLProtocol, URLSessionDataDelegate {

    private var relaySession: URLSession?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        relayRequest()
    }

    override func stopLoading() {
        relaySession?.invalidateAndCancel()
    }

    func relayRequest() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CannedBackendURLProtocol.self]
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        relaySession = session
        session.dataTask(with: request).resume()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}

private final class AsynchronousRelayURLProtocol: SynchronousRelayURLProtocol {

    override func startLoading() {
        RunLoop.main.perform {
            self.relayRequest()
        }
    }
}
