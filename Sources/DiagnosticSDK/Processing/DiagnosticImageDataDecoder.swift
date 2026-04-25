import Foundation
import ImageIO
import UIKit

enum DiagnosticImageDataDecoder {
    private static let maxAnimFrames: Int = 200

    static func makeUIImage(from data: Data) -> UIImage? {
        if data.isEmpty { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let type = (CGImageSourceGetType(source) as String?)?.lowercased() ?? ""
        let count = CGImageSourceGetCount(source)
        if count <= 1 {
            if let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
            }
            return UIImage(data: data)
        }
        let cap = min(count, Self.maxAnimFrames)
        var images: [UIImage] = []
        var total: Double = 0
        for i in 0..<cap {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            let dt = frameDelay(source: source, index: i)
            total += dt
            images.append(UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up))
        }
        if images.isEmpty { return UIImage(data: data) }
        if images.count == 1 { return images[0] }
        if type.contains("gif") || type.contains("png") {
            return UIImage.animatedImage(with: images, duration: max(total, 0.15))
        }
        return UIImage.animatedImage(with: images, duration: max(total / Double(images.count), 0.1))
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        var delay: Double = 0.1
        guard let info = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any] else { return delay }
        if let gif = info[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            if let u = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, u > 0.0 { return u }
            if let d = gif[kCGImagePropertyGIFDelayTime as String] as? Double, d > 0.0 { return d }
        }
        if let png = info[kCGImagePropertyPNGDictionary as String] as? [String: Any] {
            if let u = png[kCGImagePropertyAPNGUnclampedDelayTime as String] as? NSNumber, u.doubleValue > 0.0 { return u.doubleValue }
            if let d = png[kCGImagePropertyAPNGDelayTime as String] as? NSNumber, d.doubleValue > 0.0 { return d.doubleValue }
        }
        return delay
    }
}
