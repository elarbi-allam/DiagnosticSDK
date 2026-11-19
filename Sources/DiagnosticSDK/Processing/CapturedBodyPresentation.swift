import Foundation

enum CapturedBodyPresentation {

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
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

extension RequestDetails {
    var contentType: String? {
        NetworkContentType.contentTypeHeader(in: headers)
    }

    var formattedBody: FormattedHTTPBody {
        CapturedBodyPresentation.formattedBody(data: bodyData, contentType: contentType, omission: bodyOmission, sizeBytes: bodySizeBytes)
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
        CapturedBodyPresentation.formattedBody(data: bodyData, contentType: contentType, omission: bodyOmission, sizeBytes: bodySizeBytes)
    }

    var bodyTruncationNotice: String? {
        CapturedBodyPresentation.truncationNotice(isTruncated: isBodyTruncated, sizeBytes: bodySizeBytes)
    }
}
