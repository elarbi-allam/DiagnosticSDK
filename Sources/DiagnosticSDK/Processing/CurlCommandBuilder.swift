import Foundation

enum CurlCommandBuilder {

    private static let headersRecomputedByCurl: Set<String> = ["content-length", "accept-encoding", "connection"]

    static func command(for request: RequestDetails) -> String {
        var arguments = ["curl", "-X", request.method.uppercased(), quoted(request.url)]
        let headers = (request.headers ?? [:])
            .filter { !headersRecomputedByCurl.contains($0.key.lowercased()) }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        for header in headers {
            arguments += ["-H", quoted("\(header.key): \(header.value)")]
        }
        if let bodyData = request.bodyData, !bodyData.isEmpty, request.isBodyTruncated != true {
            if let bodyText = String(data: bodyData, encoding: .utf8) {
                arguments += ["--data-raw", quoted(bodyText)]
            } else {
                arguments += ["--data-binary", quoted("@request-body.bin")]
            }
        }
        return arguments.joined(separator: " ")
    }

    private static func quoted(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
