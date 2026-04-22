import Foundation

enum NetworkEventBuilder {
    
    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        latency: Double,
        screenName: String?,
        screenVisitId: Int?,
        error: Error? = nil
    ) -> NetworkEvent {
        
        let filteredHeaders = SensitiveDataFilter.sanitize(
            headers: request.allHTTPHeaderFields ?? [:]
        )
        
        func contentType(from headers: [String: String]?) -> String? {
            guard let headers = headers else { return nil }
            let contentTypeKey = headers.keys.first { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }
            guard let key = contentTypeKey else { return nil }
            let rawContentType = headers[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let contentType = rawContentType, !contentType.isEmpty else { return nil }
            return contentType
        }
        
        func isJSONContentType(_ contentType: String?) -> Bool {
            guard let contentType = contentType?.lowercased() else { return false }
            return contentType.contains("application/json") || contentType.contains("+json")
        }
        
        func unsupportedContentTypeMessage(from headers: [String: String]?) -> String {
            let resolvedContentType = contentType(from: headers) ?? "unknown"
            return "can't save this type of content: \(resolvedContentType)"
        }
        
        let requestBody: String?
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            if isJSONContentType(contentType(from: request.allHTTPHeaderFields)) {
                requestBody = String(data: bodyData, encoding: .utf8)
            } else {
                requestBody = unsupportedContentTypeMessage(from: request.allHTTPHeaderFields)
            }
        } else {
            requestBody = nil
        }
        
        let requestModel = RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: filteredHeaders,
            body: requestBody,
            screenName: screenName,
            screenVisitId: screenVisitId
        )
        
        let httpResponse = response as? HTTPURLResponse
        let responseHeaders = httpResponse?.allHeaderFields as? [String: String] ?? [:]
        
        let bodyBase64: String?
        let bodySize = data?.count ?? 0
        
        if let responseData = data, !responseData.isEmpty {
            if isJSONContentType(contentType(from: responseHeaders)) {
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
            durationMs: Int(latency * 1000)
        )
    }
}
