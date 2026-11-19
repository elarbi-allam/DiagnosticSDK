import Foundation

enum CapturedBodyPresentation {

    private static let legacyUnsupportedContentPrefix = "can't save this type of content:"

    static func isLegacyUnsupportedContentPlaceholder(_ storedValue: String?, encoding: CapturedBodyEncoding?) -> Bool {
        encoding == nil && storedValue?.hasPrefix(legacyUnsupportedContentPrefix) == true
    }

    static let legacyUnsupportedContentBody = FormattedHTTPBody.notCaptured("Not captured by the SDK version that recorded this session.")

    static func formattedBody(
        data: Data?,
        contentType: String?,
        omission: CapturedBodyOmission?,
        sizeBytes: Int
    ) -> FormattedHTTPBody {
        let formattedSize = formattedByteCount(sizeBytes)
        switch omission {
        case .binaryContent:
            return .notCaptured("Binary content not captured (\(contentType ?? "unknown type"), \(formattedSize)).")
        case .notObservableForTaskType:
            return .notCaptured("Body of \(formattedSize) not observable for this request type (downloaded to a file or streamed).")
        case .memoryBudget:
            return .notCaptured("Body of \(formattedSize) discarded to keep the session within its memory budget.")
        case nil:
            return HTTPPayloadFormatter.format(bodyData: data, contentType: contentType)
        }
    }

    static func truncationNotice(isTruncated: Bool?, sizeBytes: Int) -> String? {
        guard isTruncated == true else { return nil }
        let storedSize = formattedByteCount(CapturedBody.maximumStoredByteCount)
        return "Showing the first \(storedSize) of \(formattedByteCount(sizeBytes))."
    }

    static func formattedByteCount(_ byteCount: Int) -> String {
        switch byteCount {
        case ..<1_000:
            return byteCount == 1 ? "1 byte" : "\(byteCount) bytes"
        case ..<1_000_000:
            return String(format: "%.1f KB", locale: Locale(identifier: "en_US_POSIX"), Double(byteCount) / 1_000)
        default:
            return String(format: "%.1f MB", locale: Locale(identifier: "en_US_POSIX"), Double(byteCount) / 1_000_000)
        }
    }
}

extension RequestDetails {
    var contentType: String? {
        NetworkContentType.contentTypeHeader(in: headers)
    }

    var formattedBody: FormattedHTTPBody {
        guard !CapturedBodyPresentation.isLegacyUnsupportedContentPlaceholder(bodyBase64, encoding: bodyEncoding) else {
            return CapturedBodyPresentation.legacyUnsupportedContentBody
        }
        return CapturedBodyPresentation.formattedBody(data: bodyData, contentType: contentType, omission: bodyOmission, sizeBytes: bodySizeBytes)
    }

    var bodyTruncationNotice: String? {
        CapturedBodyPresentation.truncationNotice(isTruncated: isBodyTruncated, sizeBytes: bodySizeBytes)
    }
}

extension ResponseDetails {
    var contentType: String? {
        NetworkContentType.contentTypeHeader(in: headers)
    }

    var formattedBody: FormattedHTTPBody {
        guard !CapturedBodyPresentation.isLegacyUnsupportedContentPlaceholder(bodyBase64, encoding: bodyEncoding) else {
            return CapturedBodyPresentation.legacyUnsupportedContentBody
        }
        return CapturedBodyPresentation.formattedBody(data: bodyData, contentType: contentType, omission: bodyOmission, sizeBytes: bodySizeBytes)
    }

    var bodyTruncationNotice: String? {
        CapturedBodyPresentation.truncationNotice(isTruncated: isBodyTruncated, sizeBytes: bodySizeBytes)
    }
}
