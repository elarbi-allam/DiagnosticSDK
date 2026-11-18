import Foundation

struct CapturedBody {
    static let maximumStoredByteCount = 2 * 1024 * 1024

    let storedValue: String?
    let encoding: CapturedBodyEncoding?
    let sizeBytes: Int
    let isTruncated: Bool
    let omission: CapturedBodyOmission?

    init(data: Data?, receivedByteCount: Int? = nil, contentType: String?) {
        let sizeBytes = max(receivedByteCount ?? 0, data?.count ?? 0)

        guard sizeBytes > 0 else {
            self.init(storedValue: nil, encoding: nil, sizeBytes: 0, isTruncated: false, omission: nil)
            return
        }

        let kind = NetworkContentType.kind(ofContentType: contentType, sniffing: data)
        guard let data, !data.isEmpty, kind.isCapturable else {
            self.init(storedValue: nil, encoding: nil, sizeBytes: sizeBytes, isTruncated: false, omission: .binaryContent)
            return
        }

        let storedData = data.prefix(Self.maximumStoredByteCount)
        let isTruncated = sizeBytes > storedData.count
        if kind.isTextual, let text = Self.decodeText(storedData, contentType: contentType, toleratingCutCharacter: isTruncated) {
            self.init(storedValue: text, encoding: .text, sizeBytes: sizeBytes, isTruncated: isTruncated, omission: nil)
        } else {
            self.init(storedValue: storedData.base64EncodedString(), encoding: .base64, sizeBytes: sizeBytes, isTruncated: isTruncated, omission: nil)
        }
    }

    private init(storedValue: String?, encoding: CapturedBodyEncoding?, sizeBytes: Int, isTruncated: Bool, omission: CapturedBodyOmission?) {
        self.storedValue = storedValue
        self.encoding = encoding
        self.sizeBytes = sizeBytes
        self.isTruncated = isTruncated
        self.omission = omission
    }

    static func data(fromStoredValue storedValue: String?, encoding: CapturedBodyEncoding?, contentType: String?) -> Data? {
        guard let storedValue, !storedValue.isEmpty else { return nil }
        switch encoding {
        case .text:
            let textEncoding = NetworkContentType.textEncoding(of: contentType) ?? .utf8
            return storedValue.data(using: textEncoding) ?? Data(storedValue.utf8)
        case .base64:
            return Data(base64Encoded: storedValue)
        case nil:
            return Data(base64Encoded: storedValue) ?? Data(storedValue.utf8)
        }
    }

    private static func decodeText(_ data: Data, contentType: String?, toleratingCutCharacter: Bool) -> String? {
        let textEncoding = NetworkContentType.textEncoding(of: contentType) ?? .utf8
        let maximumCutCharacterByteCount = toleratingCutCharacter ? 3 : 0
        for droppedByteCount in 0...maximumCutCharacterByteCount where droppedByteCount < data.count {
            if let text = String(data: data.dropLast(droppedByteCount), encoding: textEncoding) {
                return text
            }
        }
        return nil
    }
}

extension RequestDetails {
    var bodyData: Data? {
        CapturedBody.data(
            fromStoredValue: bodyBase64,
            encoding: bodyEncoding ?? .text,
            contentType: NetworkContentType.contentTypeHeader(in: headers)
        )
    }
}

extension ResponseDetails {
    var bodyData: Data? {
        CapturedBody.data(
            fromStoredValue: bodyBase64,
            encoding: bodyEncoding,
            contentType: NetworkContentType.contentTypeHeader(in: headers)
        )
    }
}
