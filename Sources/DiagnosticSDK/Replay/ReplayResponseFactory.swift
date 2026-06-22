import Foundation

public struct ReplayMockPayload {
    public let response: HTTPURLResponse
    public let bodyData: Data?

    public init(response: HTTPURLResponse, bodyData: Data?) {
        self.response = response
        self.bodyData = bodyData
    }
}

public final class ReplayResponseFactory {
    public init() {}

    public func makePayload(for request: URLRequest, from interaction: NetworkInteraction) -> ReplayMockPayload? {
        guard let requestURL = request.url else { return nil }

        let statusCode = interaction.response?.status ?? 200
        let headers = interaction.response?.headers
        guard
            let response = HTTPURLResponse(
                url: requestURL,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )
        else {
            return nil
        }

        let bodyData = decodeBody(from: interaction.response?.bodyBase64)
        return ReplayMockPayload(response: response, bodyData: bodyData)
    }

    private func decodeBody(from bodyBase64: String?) -> Data? {
        guard let bodyBase64 else { return nil }

        if let decodedBody = Data(base64Encoded: bodyBase64) {
            return decodedBody
        }

        return bodyBase64.data(using: .utf8)
    }
}
