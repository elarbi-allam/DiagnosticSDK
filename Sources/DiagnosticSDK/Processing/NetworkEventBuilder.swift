import Foundation

enum NetworkEventBuilder {
    
    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        latency: Double,
        error: Error? = nil  // Optional: capture any error during request
    ) -> NetworkEvent {
        
        // Sanitize sensitive headers
        let filteredHeaders = SensitiveDataFilter.sanitize(
            headers: request.allHTTPHeaderFields ?? [:]
        )
        
        // Build request model
        let requestModel = RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: filteredHeaders,
            body: request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        )
        
        // Cast response to HTTPURLResponse
        let httpResponse = response as? HTTPURLResponse
        
        // Prepare body as Base64
        let bodyBase64 = data?.base64EncodedString()
        let bodySize = data?.count ?? 0
        
        // Build response model
        let responseModel = ResponseModel(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: httpResponse?.allHeaderFields as? [String: String] ?? [:],
            bodyBase64: bodyBase64,
            bodySizeBytes: bodySize,
            errorDescription: error?.localizedDescription
        )
        
        // Build final network event
        return NetworkEvent(
            request: requestModel,
            response: responseModel,
            timestamp: Date()
        )
    }
}
