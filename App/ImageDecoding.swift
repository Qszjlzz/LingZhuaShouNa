import ImageIO
import UIKit

extension UIImage {
    static func downsampled(data: Data, maxPixelSize: Int = 2048) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
              ] as CFDictionary)
        else { return nil }
        return UIImage(cgImage: image)
    }
}
