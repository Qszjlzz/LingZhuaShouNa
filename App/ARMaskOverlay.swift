import CoreGraphics
import SwiftUI

struct ARMaskOverlay: View {
    let mask: ARMask
    let color: Color

    var body: some View {
        ZStack {
            if let image = mask.rasterImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .renderingMode(.template)
                    .foregroundStyle(color)
            }

            if mask.points.count >= 3 {
                ARMaskContour(mask: mask)
                    .stroke(.black.opacity(0.72), style: StrokeStyle(lineWidth: 4.6, lineCap: .round, lineJoin: .round))
                ARMaskContour(mask: mask)
                    .stroke(.white.opacity(0.96), style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct ARMaskContour: Shape {
    let mask: ARMask

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = mask.points.first else { return path }
        path.move(to: point(first, in: rect))
        for point in mask.points.dropFirst() {
            path.addLine(to: self.point(point, in: rect))
        }
        path.closeSubpath()
        return path
    }

    private func point(_ maskPoint: ARMaskPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(maskPoint.x) * rect.width,
            y: rect.minY + CGFloat(maskPoint.y) * rect.height
        )
    }
}

private extension ARMask {
    var rasterImage: CGImage? {
        guard let rasterWidth, let rasterHeight, let rasterAlpha, hasRaster else { return nil }
        var pixels = [UInt8](repeating: 255, count: rasterWidth * rasterHeight * 4)
        rasterAlpha.withUnsafeBytes { alphaBytes in
            guard let alpha = alphaBytes.bindMemory(to: UInt8.self).baseAddress else { return }
            for index in 0..<(rasterWidth * rasterHeight) {
                pixels[index * 4 + 3] = alpha[index] >= 150 ? 235 : 0
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: rasterWidth,
            height: rasterHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: rasterWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
