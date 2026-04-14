import Foundation

enum NetworkEventBuilder {
    
    static func build(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        latency: Double,
        error: Error? = nil
    ) -> NetworkEvent {
        
        // Sanitize sensitive headers
        let filteredHeaders = SensitiveDataFilter.sanitize(
            headers: request.allHTTPHeaderFields ?? [:]
        )
        
        // Fetch the current screen
        let activeScreen = DiagnosticContext.shared.currentScreen
        
        // Helper function to check if headers contain "application/json"
        func isJSONContent(headers: [String: String]?) -> Bool {
            guard let headers = headers else { return false }
            let contentTypeKey = headers.keys.first { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }
            guard let key = contentTypeKey, let contentTypeValue = headers[key] else { return false }
            return contentTypeValue.lowercased().contains("application/json")
        }
        
        // --- 1. FILTER REQUEST BODY ---
        let requestIsJSON = isJSONContent(headers: request.allHTTPHeaderFields)
        let requestBody: String?
        
        if requestIsJSON {
            // Si c'est du JSON, on extrait le body normalement
            requestBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
        } else {
            // Sinon, on met le message de protection pour ne pas alourdir la RAM
            requestBody = "can't save this content type"
        }
        
        // Build request model
        let requestModel = RequestModel(
            url: request.url?.absoluteString ?? "",
            method: request.httpMethod ?? "UNKNOWN",
            headers: filteredHeaders,
            body: requestBody,
            screenName: activeScreen
        )
        
        // --- 2. FILTER RESPONSE BODY ---
        let httpResponse = response as? HTTPURLResponse
        let responseHeaders = httpResponse?.allHeaderFields as? [String: String] ?? [:]
        
        let responseIsJSON = isJSONContent(headers: responseHeaders)
        let bodyBase64: String?
        let bodySize = data?.count ?? 0
        
        if responseIsJSON {
            // Si c'est du JSON, on encode en Base64
            bodyBase64 = data?.base64EncodedString()
        } else {
            // Sinon, on bloque le gros fichier binaire (image, vidéo, etc.)
            bodyBase64 = "can't save this content type"
        }
        
        // Build response model
        let responseModel = ResponseModel(
            statusCode: httpResponse?.statusCode ?? 0,
            headers: responseHeaders,
            bodyBase64: bodyBase64,
            bodySizeBytes: bodySize, // On garde la taille réelle pour l'information, même si on ne sauve pas le body !
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