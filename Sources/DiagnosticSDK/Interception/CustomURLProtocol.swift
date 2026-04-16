import Foundation

/// Exposed to Objective-C runtime for protocol injection.
@objc(DiagnosticURLProtocol)
class CustomURLProtocol: URLProtocol {
    
    static var interceptor: URLSessionInterceptor?
    
    // 2. THE SECRET KEY (method to prevent infinite loops)
    private static let handledKey = "DiagnosticSDK_RequestHandledKey"
    private static let session = URLSession(configuration: .default)
    
    private var datatask: URLSessionDataTask?
    private var requestId: String?
    private var startTime: Date?
    
    override class func canInit(with request: URLRequest) -> Bool {
        // A. Only handle real web requests (HTTP/HTTPS)
        guard let scheme = request.url?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        
        // B. ANTI-LOOP SAFETY: If the request already has our tag, let Apple handle it.
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        
        // C. Otherwise, intercept it.
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let interceptor = Self.interceptor else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        startTime = Date()
        requestId = interceptor.handleRequest(request)
        
        // 3. CLONE AND TAG: Copy the request and attach our secret key.
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        
        
        datatask = Self.session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Send response information to the tracker
            if let id = self.requestId, let start = self.startTime {
                interceptor.handleResponse(
                    id: id,
                    response: response,
                    data: data,
                    startTime: start
                )
            }
            
            // 5. ERROR HANDLING (Important to avoid freezing the app)
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            
            // Return data to the host application as usual
            if let response = response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            
            if let data = data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            
            self.client?.urlProtocolDidFinishLoading(self)
        }
        
        datatask?.resume()
    }
    
    override func stopLoading() {
        datatask?.cancel()
    }
}
