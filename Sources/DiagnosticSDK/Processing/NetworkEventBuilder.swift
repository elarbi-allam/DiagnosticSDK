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
        let requestBody: String?
        
        // On vérifie d'abord s'il y a vraiment un body
        if let bodyData = request.httpBody, !bodyData.isEmpty {
            if isJSONContent(headers: request.allHTTPHeaderFields) {
                requestBody = String(data: bodyData, encoding: .utf8)
            } else {
                requestBody = "can't save this content type"
            }
        } else {
            // Le body est vide (ex: Requête GET), on le laisse à nil
            requestBody = nil
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
        
        let bodyBase64: String?
        let bodySize = data?.count ?? 0
        
        // On vérifie d'abord si la réponse contient de la donnée
        if let responseData = data, !responseData.isEmpty {
            if isJSONContent(headers: responseHeaders) {
                bodyBase64 = responseData.base64EncodedString()
            } else {
                bodyBase64 = "can't save this content type"
            }
        } else {
            // Pas de donnée dans la réponse, on laisse à nil
            bodyBase64 = nil
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