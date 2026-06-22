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
        let imageSourceType = (CGImageSourceGetType(source) as String?)?.lowercased() ?? ""
        let frameCount = CGImageSourceGetCount(source)
        if frameCount <= 1 {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
            }
            return UIImage(data: data)
        }
        let maxFrameCountToDecode = min(frameCount, Self.maxAnimFrames)
        var decodedFrames: [UIImage] = []
        var totalAnimationDuration: Double = 0
        for frameIndex in 0..<maxFrameCountToDecode {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, frameIndex, nil) else { continue }
            let frameDuration = frameDelay(source: source, index: frameIndex)
            totalAnimationDuration += frameDuration
            decodedFrames.append(UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up))
        }
        if decodedFrames.isEmpty { return UIImage(data: data) }
        if decodedFrames.count == 1 { return decodedFrames[0] }
        if imageSourceType.contains("gif") || imageSourceType.contains("png") {
            return UIImage.animatedImage(with: decodedFrames, duration: max(totalAnimationDuration, 0.15))
        }
        return UIImage.animatedImage(
            with: decodedFrames,
            duration: max(totalAnimationDuration / Double(decodedFrames.count), 0.1)
        )
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        var delay: Double = 0.1
        guard let info = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any] else { return delay }
        if let gif = info[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
            if let unclampedDelay = gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double,
               unclampedDelay > 0.0 {
                return unclampedDelay
            }
            if let clampedDelay = gif[kCGImagePropertyGIFDelayTime as String] as? Double,
               clampedDelay > 0.0 {
                return clampedDelay
            }
        }
        if let png = info[kCGImagePropertyPNGDictionary as String] as? [String: Any] {
            if let unclampedDelay = png[kCGImagePropertyAPNGUnclampedDelayTime as String] as? NSNumber,
               unclampedDelay.doubleValue > 0.0 {
                return unclampedDelay.doubleValue
            }
            if let clampedDelay = png[kCGImagePropertyAPNGDelayTime as String] as? NSNumber,
               clampedDelay.doubleValue > 0.0 {
                return clampedDelay.doubleValue
            }
        }
        return delay
    }
}
