import XCTest
@testable import DiagnosticSDK

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

final class SessionDelegateProxyTests: XCTestCase {

    private var eventObserver: NetworkEventObserverSpy!
    private var hostDelegate: HostSessionDelegateSpy!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        DiagnosticSDKNetworkHooks.installHooks()
        eventObserver = NetworkEventObserverSpy()
        DiagnosticSDKNetworkHooks.eventObserver = eventObserver
        hostDelegate = HostSessionDelegateSpy()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CannedResponseURLProtocol.self]
        session = URLSession(configuration: configuration, delegate: hostDelegate, delegateQueue: nil)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        DiagnosticSDKNetworkHooks.eventObserver = nil
        session = nil
        hostDelegate = nil
        eventObserver = nil
        super.tearDown()
    }

    func testSessionExposesTheHostDelegate() {
        XCTAssertTrue(session.delegate === hostDelegate)
        XCTAssertNotNil(session.delegate as? HostSessionDelegateSpy)
    }

    func testDelegateCallbacksReachBothTheHostAndTheObserver() {
        let completion = expectation(description: "host delegate completion")
        hostDelegate.onComplete = { completion.fulfill() }

        session.dataTask(with: URL(string: "https://example.invalid/profile")!).resume()

        wait(for: [completion], timeout: 5)
        XCTAssertEqual(hostDelegate.receivedData, CannedResponseURLProtocol.body)
        XCTAssertEqual(eventObserver.receivedData, CannedResponseURLProtocol.body)
        XCTAssertEqual(eventObserver.sessionDelegateCompletionCount, 1)
    }
}

private final class HostSessionDelegateSpy: NSObject, URLSessionDataDelegate {

    private let lock = NSLock()
    private var accumulatedData = Data()
    var onComplete: (() -> Void)?

    var receivedData: Data {
        lock.lock()
        defer { lock.unlock() }
        return accumulatedData
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        accumulatedData.append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?()
    }
}

private final class NetworkEventObserverSpy: NSObject, DiagnosticSDKNetworkEventObserving {

    private let lock = NSLock()
    private var accumulatedData = Data()
    private var completionCount = 0

    var receivedData: Data {
        lock.lock()
        defer { lock.unlock() }
        return accumulatedData
    }

    var sessionDelegateCompletionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return completionCount
    }

    func networkTaskWillResume(_ task: URLSessionTask) {}

    func networkTask(_ task: URLSessionTask, didReceiveResponseData data: Data) {
        lock.lock()
        accumulatedData.append(data)
        lock.unlock()
    }

    func networkTask(_ task: URLSessionTask, didCompleteWithResponseBody responseBody: Data?, error: Error?) {}

    func networkTask(_ task: URLSessionTask, didCompleteInSessionDelegateWithError error: Error?) {
        lock.lock()
        completionCount += 1
        lock.unlock()
    }

    func networkTaskDidFinishTransfer(_ task: URLSessionTask) {}

    func networkTask(_ task: URLSessionTask, didFinishCollectingMetrics metrics: URLSessionTaskMetrics) {}
}

private final class CannedResponseURLProtocol: URLProtocol {

    static let body = Data(#"{"name":"diagnostic"}"#.utf8)

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
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
