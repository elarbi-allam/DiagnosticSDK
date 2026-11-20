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
    private static let transportHeaderNames: Set<String> = [
        "content-encoding", "content-length", "transfer-encoding", "connection", "keep-alive"
    ]

    public init() {}

    public static func canReplay(_ interaction: NetworkInteraction) -> Bool {
        guard let response = interaction.response, let headers = response.headers, !headers.isEmpty else {
            return false
        }
        guard response.bodyEncoding != nil || response.bodyBase64 == nil else {
            return NetworkContentType.isJSON(NetworkContentType.contentTypeHeader(in: headers))
        }
        return response.isBodyTruncated != true && response.bodyOmission == nil
    }

    public func makePayload(for request: URLRequest, from interaction: NetworkInteraction) -> ReplayMockPayload? {
        guard let requestURL = request.url else { return nil }

        let statusCode = interaction.response?.status ?? 200
        let bodyData = interaction.response?.bodyData
        guard
            let response = HTTPURLResponse(
                url: requestURL,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: Self.replayedHeaders(from: interaction.response?.headers, bodyByteCount: bodyData?.count ?? 0)
            )
        else {
            return nil
        }

        return ReplayMockPayload(response: response, bodyData: bodyData)
    }

    private static func replayedHeaders(from recordedHeaders: [String: String]?, bodyByteCount: Int) -> [String: String]? {
        guard let recordedHeaders else { return nil }
        var headers = recordedHeaders.filter { !transportHeaderNames.contains($0.key.lowercased()) }
        headers["Content-Length"] = String(bodyByteCount)
        return headers
    }
}
