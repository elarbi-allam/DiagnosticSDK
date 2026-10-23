import Foundation

enum NetworkEventBuilder {
    
    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
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
        
        let bodyBase64: String?
        let bodySize = data?.count ?? 0
        
        if let responseData = data, !responseData.isEmpty {
            if NetworkContentType.isJSON(contentType(from: responseHeaders)) {
                bodyBase64 = responseData.base64EncodedString()
            } else {
                bodyBase64 = unsupportedContentTypeMessage(from: responseHeaders)
            }
        } else {
            bodyBase64 = nil
        }
        
        let responseModel = ResponseModel(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: responseHeaders,
            bodyBase64: bodyBase64,
            bodySizeBytes: bodySize,
            errorDescription: error?.localizedDescription
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
        let requestBody: String?
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            if NetworkContentType.isJSON(contentType(from: requestHeaders)) {
                requestBody = String(data: bodyData, encoding: .utf8)
            } else {
                requestBody = unsupportedContentTypeMessage(from: requestHeaders)
            }
        } else {
            requestBody = nil
        }
        
        return RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: requestHeaders,
            body: requestBody,
            screenName: screenName,
            screenVisitId: screenVisitId
        )
    }
    
    private static func contentType(from headers: [String: String]?) -> String? {
        guard let headers = headers else { return nil }
        let contentTypeKey = headers.keys.first { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }
        guard let key = contentTypeKey else { return nil }
        let rawContentType = headers[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let contentType = rawContentType, !contentType.isEmpty else { return nil }
        return contentType
    }
    
    private static func unsupportedContentTypeMessage(from headers: [String: String]?) -> String {
        let resolvedContentType = contentType(from: headers) ?? "unknown"
        return "can't save this type of content: \(resolvedContentType)"
    }
}
