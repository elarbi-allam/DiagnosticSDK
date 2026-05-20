import Foundation

final class ReplayDeliveryService {
    private let responseFactory: ReplayResponseFactory

    init(responseFactory: ReplayResponseFactory = ReplayResponseFactory()) {
        self.responseFactory = responseFactory
    }

    func makePayload(
        request: URLRequest,
        interaction: NetworkInteraction
    ) -> ReplayMockPayload? {
        responseFactory.makePayload(for: request, from: interaction)
    }

    func deliver(
        payload: ReplayMockPayload,
        via protocolHandler: URLProtocol
    ) {
        protocolHandler.client?.urlProtocol(protocolHandler, didReceive: payload.response, cacheStoragePolicy: .notAllowed)
        if let bodyData = payload.bodyData {
            protocolHandler.client?.urlProtocol(protocolHandler, didLoad: bodyData)
        }
        protocolHandler.client?.urlProtocolDidFinishLoading(protocolHandler)
    }
}
