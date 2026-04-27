import Foundation

enum NetworkImagePreviewEligibility {
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "heif", "hif", "tiff", "tif",
        "ico", "jpe", "jfif", "jfi", "pjpeg", "pjp", "apng", "avif", "jxl", "qoi", "icns", "psd", "tga", "exr", "bpg", "raw", "dng", "heics"
    ]

    static func canPreviewRequestImage(_ interaction: NetworkInteraction) -> Bool {
        guard interaction.request.method.uppercased() == "GET" else { return false }
        guard let url = URL(string: interaction.request.url) else { return false }
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            return true
        }
        if let requestHeaders = interaction.request.headers,
           let accept = requestHeaders.first(where: { $0.key.caseInsensitiveCompare("Accept") == .orderedSame })?.value.lowercased() {
            if accept.contains("image/") { return true }
        }
        if let responseHeaders = interaction.response?.headers {
            let contentType = responseHeaders.first(where: {
                $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame
            })?.value.lowercased()
            if contentType?.contains("image/") == true {
                return true
            }
        }
        let queryLower = url.query?.lowercased() ?? ""
        if url.pathExtension.isEmpty,
           queryLower.contains("format=png") || queryLower.contains("type=image") {
            return true
        }
        return false
    }
}
