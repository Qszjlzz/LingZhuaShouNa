import CoreML
import CoreGraphics
import UIKit

struct EdgeSAMSegmentationService {
    func refine(_ items: [DetectedItem], in image: CGImage) async -> [DetectedItem] {
        // EdgeSAM is expensive and its point decoder can move tight masks by a
        // few pixels. Restrict it to suspicious full-frame regions where the
        // refinement has a clear quality target.
        let candidates = items.filter { ($0.arMask?.rasterCoverage ?? 0) > 0.35 }
        guard !candidates.isEmpty else { return items }
        return await Task.detached(priority: .userInitiated) {
            guard let models = Self.models,
                  let prepared = Self.prepare(image)
            else { return items }

            do {
                let encoderInput = try MLDictionaryFeatureProvider(dictionary: ["image": prepared.tensor])
                let encoderOutput = try models.encoder.prediction(from: encoderInput)
                guard let embeddings = encoderOutput.featureValue(for: "image_embeddings")?.multiArrayValue else {
                    return items
                }

                return items.map { item in
                    guard candidates.contains(where: { $0.id == item.id }) else { return item }
                    guard let hint = item.arHint,
                          let mask = try? Self.decode(
                            hint: hint,
                            embeddings: embeddings,
                            prepared: prepared,
                            decoder: models.decoder
                          )
                    else { return item }
                    var refined = item
                    refined.arMask = mask
                    refined.arHint = Self.hint(from: mask)
                    return refined
                }
            } catch {
                return items
            }
        }.value
    }

    private static let models: Models? = {
        let configuration = MLModelConfiguration()
#if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly
#else
        configuration.computeUnits = .all
#endif
        guard let encoderURL = modelURL(named: "edge_sam_encoder"),
              let decoderURL = modelURL(named: "edge_sam_decoder"),
              let encoder = try? MLModel(contentsOf: encoderURL, configuration: configuration),
              let decoder = try? MLModel(contentsOf: decoderURL, configuration: configuration)
        else { return nil }
        return Models(encoder: encoder, decoder: decoder)
    }()

    private static func modelURL(named name: String) -> URL? {
        let bundles = [Bundle.main] + Bundle.allBundles
        for ext in ["mlmodelc", "mlpackage"] {
            if let url = bundles.lazy.compactMap({ $0.url(forResource: name, withExtension: ext) }).first {
                return url
            }
        }
        return nil
    }

    private static func prepare(_ image: CGImage) -> PreparedImage? {
        let inputSize = 1024
        let scale = min(CGFloat(inputSize) / CGFloat(image.width), CGFloat(inputSize) / CGFloat(image.height))
        let contentWidth = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let contentHeight = max(1, Int((CGFloat(image.height) * scale).rounded()))
        var pixels = [UInt8](repeating: 0, count: inputSize * inputSize * 4)
        guard let context = CGContext(
            data: &pixels,
            width: inputSize,
            height: inputSize,
            bitsPerComponent: 8,
            bytesPerRow: inputSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight))

        guard let tensor = try? MLMultiArray(shape: [1, 3, 1024, 1024], dataType: .float32) else { return nil }
        let values = tensor.dataPointer.assumingMemoryBound(to: Float.self)
        let planeSize = inputSize * inputSize
        let mean: [Float] = [123.675, 116.28, 103.53]
        let standardDeviation: [Float] = [58.395, 57.12, 57.375]
        for y in 0..<contentHeight {
            for x in 0..<contentWidth {
                let pixelIndex = (y * inputSize + x) * 4
                let tensorIndex = y * inputSize + x
                let red = Float(pixels[pixelIndex + 2])
                let green = Float(pixels[pixelIndex + 1])
                let blue = Float(pixels[pixelIndex])
                values[tensorIndex] = (red - mean[0]) / standardDeviation[0]
                values[planeSize + tensorIndex] = (green - mean[1]) / standardDeviation[1]
                values[planeSize * 2 + tensorIndex] = (blue - mean[2]) / standardDeviation[2]
            }
        }
        return PreparedImage(
            tensor: tensor,
            contentWidth: contentWidth,
            contentHeight: contentHeight,
            imageWidth: image.width,
            imageHeight: image.height
        )
    }

    private static func decode(
        hint: ARHint,
        embeddings: MLMultiArray,
        prepared: PreparedImage,
        decoder: MLModel
    ) throws -> ARMask? {
        let coordinates = try MLMultiArray(shape: [1, 2, 2], dataType: .float32)
        let labels = try MLMultiArray(shape: [1, 2], dataType: .float32)
        let minX = max(0, hint.x - hint.width / 2) * Double(prepared.contentWidth)
        let maxX = min(1, hint.x + hint.width / 2) * Double(prepared.contentWidth)
        let minY = max(0, hint.y - hint.height / 2) * Double(prepared.contentHeight)
        let maxY = min(1, hint.y + hint.height / 2) * Double(prepared.contentHeight)
        coordinates[[0, 0, 0] as [NSNumber]] = NSNumber(value: minY)
        coordinates[[0, 0, 1] as [NSNumber]] = NSNumber(value: minX)
        coordinates[[0, 1, 0] as [NSNumber]] = NSNumber(value: maxY)
        coordinates[[0, 1, 1] as [NSNumber]] = NSNumber(value: maxX)
        labels[[0, 0] as [NSNumber]] = 2
        labels[[0, 1] as [NSNumber]] = 3

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "image_embeddings": embeddings,
            "point_coords": coordinates,
            "point_labels": labels
        ])
        let output = try decoder.prediction(from: input)
        guard let masks = output.featureValue(for: "masks")?.multiArrayValue,
              let scores = output.featureValue(for: "scores")?.multiArrayValue
        else { return nil }

        let candidate = (0..<4).max { scores[[0, $0] as [NSNumber]].floatValue < scores[[0, $1] as [NSNumber]].floatValue } ?? 0
        // ARMask raster images are rendered into the entire camera rect. Keep a
        // fixed full-frame grid here; the previous content-sized grid was
        // stretched to the viewport and moved masks toward the bottom/right.
        let rasterWidth = 128
        let rasterHeight = 128
        var alpha = [UInt8](repeating: 0, count: rasterWidth * rasterHeight)
        let sourceWidth = max(1, Int(ceil(Double(prepared.contentWidth) / 4)))
        let sourceHeight = max(1, Int(ceil(Double(prepared.contentHeight) / 4)))
        for y in 0..<sourceHeight {
            for x in 0..<sourceWidth {
                let value = masks[[0, candidate, y, x] as [NSNumber]].floatValue
                guard value > 0 else { continue }
                let normalizedX = (Double(x) / Double(sourceWidth)) * Double(prepared.contentWidth) / Double(prepared.imageWidth)
                let normalizedY = (Double(y) / Double(sourceHeight)) * Double(prepared.contentHeight) / Double(prepared.imageHeight)
                let targetX = min(rasterWidth - 1, max(0, Int(normalizedX * Double(rasterWidth))))
                let targetY = min(rasterHeight - 1, max(0, Int(normalizedY * Double(rasterHeight))))
                alpha[targetY * rasterWidth + targetX] = 210
            }
        }
        alpha = closedMask(alpha, width: rasterWidth, height: rasterHeight)
        guard alpha.reduce(0, { $0 + ($1 > 0 ? 1 : 0) }) >= 12 else { return nil }
        let contour = contourFromRaster(alpha, width: rasterWidth, height: rasterHeight)
        guard contour.count >= 3 else { return nil }
        return ARMask(points: contour, rasterWidth: rasterWidth, rasterHeight: rasterHeight, rasterAlpha: Data(alpha))
    }

    private static func closedMask(_ alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = alpha
        guard alpha.count == width * height, width > 2, height > 2 else { return alpha }
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let neighbors = [alpha[index - 1], alpha[index + 1], alpha[index - width], alpha[index + width]].filter { $0 > 0 }.count
                if alpha[index] == 0 && neighbors >= 3 { result[index] = 210 }
            }
        }
        return result
    }

    private static func contourFromRaster(_ alpha: [UInt8], width: Int, height: Int) -> [ARMaskPoint] {
        guard alpha.count == width * height else { return [] }
        var rows: [(y: Int, left: Int, right: Int)] = []
        for y in 1..<(height - 1) {
            var left: Int?
            var right: Int?
            for x in 1..<(width - 1) where alpha[y * width + x] > 0 {
                let index = y * width + x
                let exposed = alpha[index - 1] == 0 || alpha[index + 1] == 0 || alpha[index - width] == 0 || alpha[index + width] == 0
                guard exposed else { continue }
                if left == nil { left = x }
                right = x
            }
            if let left, let right, right > left { rows.append((y, left, right)) }
        }
        guard rows.count >= 3 else { return [] }
        let stride = max(1, rows.count / 32)
        let leftEdge = rows.enumerated().compactMap { $0.offset % stride == 0 ? ARMaskPoint(x: (Double($0.element.left) + 0.5) / Double(width), y: (Double($0.element.y) + 0.5) / Double(height)) : nil }
        let rightEdge = rows.enumerated().compactMap { $0.offset % stride == 0 ? ARMaskPoint(x: (Double($0.element.right) + 0.5) / Double(width), y: (Double($0.element.y) + 0.5) / Double(height)) : nil }
        return leftEdge + rightEdge.reversed()
    }

    private static func simplified(_ points: [ARMaskPoint]) -> [ARMaskPoint] {
        guard points.count > 36 else { return points }
        let stride = max(1, points.count / 36)
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    private static func hint(from mask: ARMask) -> ARHint {
        let minX = mask.points.map(\.x).min() ?? 0.33
        let maxX = mask.points.map(\.x).max() ?? 0.67
        let minY = mask.points.map(\.y).min() ?? 0.39
        let maxY = mask.points.map(\.y).max() ?? 0.61
        return ARHint(
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private struct Models {
        let encoder: MLModel
        let decoder: MLModel
    }

    private struct PreparedImage {
        let tensor: MLMultiArray
        let contentWidth: Int
        let contentHeight: Int
        let imageWidth: Int
        let imageHeight: Int
    }
}
