import Foundation

enum DecodedTokenExtractor {
    private static let jwtPattern = #"[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+"#

    static func extract(
        headers: [String: String]?,
        bodyRawValue: String?,
        sourcePrefix: String
    ) -> [DecodedTokenItem] {
        var orderedResults: [DecodedTokenItem] = []

        if let headers, !headers.isEmpty {
            for key in headers.keys.sorted() {
                guard let value = headers[key] else { continue }
                guard shouldInspectHeaderKey(key) else { continue }
                let source = "\(sourcePrefix) Header: \(key)"
                appendDecodedTokenIfMatch(
                    value: value,
                    source: source,
                    orderedResults: &orderedResults
                )
            }
        }

        if let bodyData = normalizedBodyData(from: bodyRawValue) {
            if let jsonObject = try? JSONSerialization.jsonObject(with: bodyData, options: [.fragmentsAllowed]) {
                traverseJSONObject(jsonObject, path: "\(sourcePrefix) Body") { nodePath, key, value in
                    guard let key, key.lowercased().contains("token") else { return }
                    let candidateValue = stringifyTokenCandidate(value)
                    appendDecodedTokenIfMatch(
                        value: candidateValue,
                        source: nodePath,
                        orderedResults: &orderedResults
                    )
                }
            } else if let bodyText = String(data: bodyData, encoding: .utf8), !bodyText.isEmpty {
                appendDecodedTokensFromKeyValueText(
                    bodyText,
                    path: "\(sourcePrefix) Body",
                    orderedResults: &orderedResults
                )
            }
        }

        return orderedResults
    }

    private static func appendDecodedTokenIfMatch(
        value: String,
        source: String,
        orderedResults: inout [DecodedTokenItem]
    ) {
        let normalizedValue = normalizedTokenCarrierValue(value)
        guard let candidate = jwtCandidate(in: normalizedValue) else { return }
        orderedResults.append(
            DecodedTokenItem(
                id: "\(source)-\(candidate)",
                source: source,
                rawToken: candidate,
                decodedJSON: decodedJWTOrFallback(candidate)
            )
        )
    }

    private static func traverseJSONObject(
        _ object: Any,
        path: String,
        visit: (_ nodePath: String, _ key: String?, _ value: Any) -> Void
    ) {
        if let fields = object as? [String: Any] {
            for key in fields.keys.sorted() {
                guard let value = fields[key] else { continue }
                let fieldPath = "\(path).\(key)"
                visit(fieldPath, key, value)
                traverseJSONObject(value, path: fieldPath, visit: visit)
            }
            return
        }

        if let elements = object as? [Any] {
            for (index, element) in elements.enumerated() {
                let elementPath = "\(path)[\(index)]"
                visit(elementPath, nil, element)
                traverseJSONObject(element, path: elementPath, visit: visit)
            }
        }
    }

    private static func appendDecodedTokensFromKeyValueText(
        _ text: String,
        path: String,
        orderedResults: inout [DecodedTokenItem]
    ) {
        let separators = CharacterSet(charactersIn: "&\n\r")
        let entries = text.components(separatedBy: separators).filter { !$0.isEmpty }
        for entry in entries {
            let pair = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { continue }
            let key = String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.lowercased().contains("token") else { continue }
            let value = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            appendDecodedTokenIfMatch(
                value: value,
                source: "\(path).\(key)",
                orderedResults: &orderedResults
            )
        }
    }

    private static func shouldInspectHeaderKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized.contains("token") || normalized == "authorization"
    }

    private static func normalizedTokenCarrierValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle common authorization prefixes and spelling variants.
        let lowercasedValue = value.lowercased()
        let prefixes = ["bearer ", "barear "]
        if let prefix = prefixes.first(where: { lowercasedValue.hasPrefix($0) }) {
            value = String(value.dropFirst(prefix.count))
        }

        if value.hasPrefix("\""), value.hasSuffix("\""), value.count > 1 {
            value.removeFirst()
            value.removeLast()
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func jwtCandidate(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: jwtPattern) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private static func normalizedBodyData(from rawValue: String?) -> Data? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let data = Data(base64Encoded: rawValue) {
            return data
        }
        return rawValue.data(using: .utf8)
    }

    private static func stringifyTokenCandidate(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }

    private static func decodedJWTOrFallback(_ token: String) -> String {
        if let decoded = decodeJWT(token) {
            return decoded
        }

        let segments = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let fallbackObject: [String: Any] = [
            "error": "JWT payload could not be decoded as JSON",
            "token": token,
            "segments": [
                "header": segments.indices.contains(0) ? segments[0] : "",
                "payload": segments.indices.contains(1) ? segments[1] : "",
                "signature": segments.indices.contains(2) ? segments[2] : ""
            ]
        ]

        guard JSONSerialization.isValidJSONObject(fallbackObject),
              let data = try? JSONSerialization.data(
                  withJSONObject: fallbackObject,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: data, encoding: .utf8) else {
            return "{\n  \"error\" : \"JWT payload could not be decoded as JSON\"\n}"
        }

        return pretty
    }

    private static func decodeJWT(_ token: String) -> String? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }

        guard
            let headerData = base64URLDecode(String(segments[0])),
            let payloadData = base64URLDecode(String(segments[1]))
        else {
            return nil
        }

        let headerObject = jsonObject(from: headerData)
        let payloadObject = jsonObject(from: payloadData)
        guard let headerObject, let payloadObject else { return nil }

        let composedObject: [String: Any] = [
            "header": headerObject,
            "payload": payloadObject,
            "signature": String(segments[2])
        ]

        guard JSONSerialization.isValidJSONObject(composedObject),
              let composedData = try? JSONSerialization.data(
                  withJSONObject: composedObject,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let pretty = String(data: composedData, encoding: .utf8)
        else {
            return nil
        }

        return pretty
    }

    private static func jsonObject(from data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: normalized)
    }
}

