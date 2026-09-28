import Foundation

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

@objc(DiagnosticReplayURLProtocol)
final class ReplayURLProtocol: URLProtocol {

    private static let matchEngine = ReplayMatchEngine()
    private static let deliveryService = ReplayDeliveryService()

    override class func canInit(with request: URLRequest) -> Bool {
        replayedInteraction(for: request) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let replayedInteraction = Self.replayedInteraction(for: request),
            let payload = Self.deliveryService.makePayload(request: request, interaction: replayedInteraction)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        if let task {
            DiagnosticSDKNetworkHooks.markTaskAsReplayed(task)
        }
        Self.deliveryService.deliver(payload: payload, via: self)
    }

    override func stopLoading() {}

    private static func replayedInteraction(for request: URLRequest) -> NetworkInteraction? {
        guard DiagnosticRuntimeState.isRunning.value, request.url?.usesHTTPScheme == true else { return nil }

        let replayState = ReplayStateMirror.current.value
        guard replayState.isReplayActive, let activeTrace = replayState.activeTrace else { return nil }

        return matchEngine.findMatch(
            for: request,
            in: activeTrace,
            disabledInteractionIDs: replayState.disabledInteractionIDs,
            queryMatchingMode: replayState.queryMatchingMode
        )
    }
}
