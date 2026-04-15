import Foundation

public final class ConsoleStore: NetworkStoreProtocol {
    
    public init() {}
    
    public func save(event: NetworkEvent) {
        let request = event.request
        let response = event.response
        
        // 1. Screen name cleanup (module stripping)
        let rawScreenName = request.screenName ?? "Background"
        let cleanScreenName = rawScreenName.components(separatedBy: ".").last ?? rawScreenName
        
        // 2. Visual logic based on status
        let status = response?.statusCode ?? 0
        let statusEmoji = (200...299).contains(status) ? "✅" : "❌"
        let methodEmoji = getMethodEmoji(request.method)
        
        // 3. Atomic message construction
        let logMessage = """
        
        ┌─────────────────── 📡 [DiagnosticSDK] ────────────────────┐
        │ 📱 SCREEN   : \(cleanScreenName.padding(toLength: 35, withPad: " ", startingAt: 0)) │
        │ \(methodEmoji) REQUEST  : \(request.method) \(request.url.suffix(30))... │
        │ \(statusEmoji) STATUS   : \(status == 0 ? "FAILED" : "\(status)") │
        │ 📦 SIZE     : \(response?.bodySizeBytes ?? 0) bytes │
        │ ⏱️ TIME     : \(event.timestamp.description.suffix(12)) │
        └──────────────────────────────────────────────────────────┘
        """
        
        print(logMessage)
    }
    
    private func getMethodEmoji(_ method: String) -> String {
        switch method.uppercased() {
        case "GET": return "🔍"
        case "POST": return "📤"
        case "PUT": return "🔄"
        case "DELETE": return "🗑️"
        default: return "🌐"
        }
    }
}
