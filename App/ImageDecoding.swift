import ImageIO
import UIKit

extension UIImage {
    static func downsampled(data: Data, maxPixelSize: Int = 2048) -> UIImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    func recognitionCGImage(maxPixelSize: Int = 2048) -> CGImage? {
        guard maxPixelSize > 0 else { return nil }
        let pixelSize: CGSize
        if let cgImage {
            switch imageOrientation {
            case .left, .right, .leftMirrored, .rightMirrored:
                pixelSize = CGSize(width: cgImage.height, height: cgImage.width)
            default:
                pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            }
            if imageOrientation == .up, max(cgImage.width, cgImage.height) <= maxPixelSize {
                return cgImage
            }
        } else {
            pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        }
        guard pixelSize.width.isFinite, pixelSize.height.isFinite,
              pixelSize.width > 0, pixelSize.height > 0
        else { return nil }
        let ratio = min(1, CGFloat(maxPixelSize) / max(pixelSize.width, pixelSize.height))
        let outputSize = CGSize(
            width: max(1, (pixelSize.width * ratio).rounded(.down)),
            height: max(1, (pixelSize.height * ratio).rounded(.down))
        )
        // Bound the destination before applying orientation; screen scale must
        // not turn a 2048-pixel photo into a 6144-pixel intermediate bitmap.
        return autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.preferredRange = .standard
            return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
                draw(in: CGRect(origin: .zero, size: outputSize))
            }.cgImage
        }
    }
}
