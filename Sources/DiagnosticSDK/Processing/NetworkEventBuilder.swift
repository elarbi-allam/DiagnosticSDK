import Foundation

enum NetworkEventBuilder {

    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        receivedByteCount: Int? = nil,
        captureId: String,
        startedAt: Date,
        timing: NetworkTiming,
        screenName: String?,
        screenVisitId: Int?,
        error: Error? = nil
    ) -> NetworkEvent {
        let requestModel = makeRequestModel(from: request, screenName: screenName, screenVisitId: screenVisitId)

        let httpResponse = response as? HTTPURLResponse
        let responseHeaders = httpResponse?.allHeaderFields as? [String: String] ?? [:]
        let responseBody = CapturedBody(
            data: data,
            receivedByteCount: receivedByteCount,
            contentType: NetworkContentType.contentTypeHeader(in: responseHeaders) ?? response?.mimeType
        )

        let responseModel = ResponseModel(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: responseHeaders,
            bodyBase64: responseBody.storedValue,
            bodySizeBytes: responseBody.sizeBytes,
            errorDescription: error?.localizedDescription,
            bodyEncoding: responseBody.encoding,
            isBodyTruncated: responseBody.isTruncated ? true : nil,
            bodyOmission: responseBody.omission
        )

        return NetworkEvent(
            request: requestModel,
            response: responseModel,
            timestamp: Date(),
            durationMs: timing.preferredDurationMs,
            captureId: captureId,
            startedAt: startedAt,
            timing: timing
        )
    }

    static func makeRequestModel(from request: URLRequest, screenName: String?, screenVisitId: Int?) -> RequestModel {
        let requestHeaders = request.allHTTPHeaderFields ?? [:]
        let requestBody = CapturedBody(
            data: request.httpBody,
            contentType: NetworkContentType.contentTypeHeader(in: requestHeaders)
        )

        return RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: requestHeaders,
            body: requestBody.storedValue,
            screenName: screenName,
            screenVisitId: screenVisitId,
            bodySizeBytes: requestBody.sizeBytes,
            bodyEncoding: requestBody.encoding,
            isBodyTruncated: requestBody.isTruncated ? true : nil,
            bodyOmission: requestBody.omission
        )
    }
}
