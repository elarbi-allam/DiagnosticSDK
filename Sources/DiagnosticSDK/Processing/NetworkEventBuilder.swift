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
        
        func isJSONContent(headers: [String: String]?) -> Bool {
            guard let headers = headers else { return false }
            let contentTypeKey = headers.keys.first { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }
            guard let key = contentTypeKey, let contentTypeValue = headers[key] else { return false }
            return contentTypeValue.lowercased().contains("application/json")
        }
        
        let requestBody: String?
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            if isJSONContent(headers: request.allHTTPHeaderFields) {
                requestBody = String(data: bodyData, encoding: .utf8)
            } else {
                requestBody = "can't save this content type"
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
            if isJSONContent(headers: responseHeaders) {
                bodyBase64 = responseData.base64EncodedString()
            } else {
                bodyBase64 = "can't save this content type"
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
