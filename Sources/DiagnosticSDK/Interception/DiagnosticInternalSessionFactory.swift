import Foundation

#if canImport(DiagnosticSDKObjC)
import DiagnosticSDKObjC
#endif

enum DiagnosticInternalSessionFactory {

    static func makeEphemeralSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = (configuration.protocolClasses ?? []).filter { protocolClass in
            ObjectIdentifier(protocolClass) != ObjectIdentifier(ReplayURLProtocol.self)
        }

        let session = URLSession(configuration: configuration)
        DiagnosticSDKNetworkHooks.excludeSessionFromCapture(session)
        return session
    }
}
