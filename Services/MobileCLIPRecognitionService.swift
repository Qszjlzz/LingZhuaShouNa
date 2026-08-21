import Accelerate
import CoreML
import Foundation
import UIKit

enum MobileCLIPError: LocalizedError {
    case imageEncoderMissing
    case categoryEmbeddingsMissing
    case invalidEmbedding
    case noDetections
    case noSemanticMatch

    var errorDescription: String? {
        switch self {
        case .imageEncoderMissing: "未找到 MobileCLIPImageEncoder.mlmodelc。"
        case .categoryEmbeddingsMissing: "未找到 category_embeddings.json。"
        case .invalidEmbedding: "MobileCLIP 未返回有效的 512 维特征。"
        case .noDetections: "未检测到可识别物体。"
        case .noSemanticMatch: "没有找到足够可靠的语义匹配。"
        }
    }
}

struct RecognitionBackendStatus: Equatable {
    let imageEncoderAvailable: Bool
    let categoryVectorCount: Int

    var semanticMatchingAvailable: Bool {
        imageEncoderAvailable && categoryVectorCount > 0
    }

    var displayName: String {
        semanticMatchingAvailable ? "YOLO + MobileCLIP" : "YOLO 实例分割（语义模型未启用）"
    }
}

/// In-memory text-feature store. The JSON must contain real, L2-normalized
/// MobileCLIP text embeddings; category names alone are intentionally not used.
final class CategoryVectorDB {
    static let shared = CategoryVectorDB()

    private let lock = NSLock()
    private var embeddings: [String: [Float]] = [:]

    private init() {
        reload()
    }

    var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !embeddings.isEmpty
    }

    var categoryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return embeddings.count
    }

    func reload() {
        let decoder = JSONDecoder()
        let documentURL = Self.cacheURL
        let bundleURL = Bundle.main.url(forResource: "category_embeddings", withExtension: "json")
        let sourceURL = FileManager.default.fileExists(atPath: documentURL.path) ? documentURL : bundleURL
        guard let sourceURL,
              let data = try? Data(contentsOf: sourceURL),
              let decoded = try? decoder.decode([String: [Float]].self, from: data)
        else { return }

        let valid = decoded.reduce(into: [String: [Float]]()) { result, entry in
            guard entry.value.count == 512,
                  let normalized = Self.normalized(entry.value)
            else { return }
            result[entry.key] = normalized
        }
        lock.lock()
        embeddings = valid
        lock.unlock()
    }

    func search(imageEmbedding: [Float], topK: Int = 3) -> [(String, Float)] {
        guard let normalized = Self.normalized(imageEmbedding), topK > 0 else { return [] }
        lock.lock()
        let currentEmbeddings = embeddings
        lock.unlock()

        return currentEmbeddings.compactMap { name, vector in
            let similarity = Self.cosineSimilarity(normalized, vector)
            return similarity.isFinite ? (name, similarity) : nil
        }
        .sorted { $0.1 > $1.1 }
        .prefix(topK)
        .map { $0 }
    }

    func addCategory(name: String, embedding: [Float]) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              embedding.count == 512,
              let normalized = Self.normalized(embedding)
        else { return }
        lock.lock()
        embeddings[name] = normalized
        lock.unlock()
    }

    func saveEmbeddingsToCache() throws {
        lock.lock()
        let snapshot = embeddings
        lock.unlock()
        let directory = Self.cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: Self.cacheURL, options: .atomic)
    }

    func getAllCategories() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return embeddings.keys.sorted()
    }

    static func cosineSimilarity(_ vector1: [Float], _ vector2: [Float]) -> Float {
        guard vector1.count == vector2.count, !vector1.isEmpty else { return 0 }
        var dot: Float = 0
        var lhsNorm: Float = 0
        var rhsNorm: Float = 0
        vDSP_dotpr(vector1, 1, vector2, 1, &dot, vDSP_Length(vector1.count))
        vDSP_svesq(vector1, 1, &lhsNorm, vDSP_Length(vector1.count))
        vDSP_svesq(vector2, 1, &rhsNorm, vDSP_Length(vector2.count))
        let denominator = sqrt(lhsNorm) * sqrt(rhsNorm)
        guard denominator > .leastNonzeroMagnitude else { return 0 }
        // CLIP cosine can be negative. The recognition confidence is exposed as 0...1.
        return min(max(dot / denominator, 0), 1)
    }

    private static func normalized(_ vector: [Float]) -> [Float]? {
        guard !vector.isEmpty else { return nil }
        var squaredLength: Float = 0
        vDSP_svesq(vector, 1, &squaredLength, vDSP_Length(vector.count))
        let length = sqrt(squaredLength)
        guard length.isFinite, length > .leastNonzeroMagnitude else { return nil }
        return vector.map { $0 / length }
    }

    private static var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recognition/category_embeddings.json")
    }
}

final class MobileCLIPFeatureExtractor: @unchecked Sendable {
    static let shared = MobileCLIPFeatureExtractor()

    private let model: MLModel?
    private let targetImageSize: CGSize

    private init(bundle: Bundle = .main) {
        let modelURL = [
            bundle.url(forResource: "mobileclip_s0_image", withExtension: "mlmodelc"),
            bundle.url(forResource: "mobileclip_s1_image", withExtension: "mlmodelc"),
            bundle.url(forResource: "MobileCLIPImageEncoder", withExtension: "mlmodelc"),
            bundle.url(forResource: "mobileclip_image_encoder", withExtension: "mlmodelc")
        ]
        .compactMap { $0 }
        .first

        if let modelURL {
            let configuration = MLModelConfiguration()
            #if targetEnvironment(simulator)
            configuration.computeUnits = .cpuOnly
            #else
            configuration.computeUnits = .all
            #endif
            model = try? MLModel(contentsOf: modelURL, configuration: configuration)
        } else {
            model = nil
        }

        if let imageDescription = model?.modelDescription.inputDescriptionsByName.values.first(where: { $0.type == .image }),
           let constraint = imageDescription.imageConstraint {
            targetImageSize = CGSize(width: constraint.pixelsWide, height: constraint.pixelsHigh)
        } else {
            // Official MobileCLIP S0/S1/S2 use 256x256. BLT is 224x224.
            targetImageSize = CGSize(width: 256, height: 256)
        }
    }

    var isAvailable: Bool { model != nil }

    func extractImageFeature(from image: UIImage) async throws -> [Float] {
        guard let model else { throw MobileCLIPError.imageEncoderMissing }
        guard let pixelBuffer = image.centerCroppedPixelBuffer(size: targetImageSize) else {
            throw MobileCLIPError.invalidEmbedding
        }

        return try await Task.detached(priority: .userInitiated) {
            guard let inputName = model.modelDescription.inputDescriptionsByName.first(where: {
                $0.value.type == .image
            })?.key
            else { throw MobileCLIPError.invalidEmbedding }

            let input = try MLDictionaryFeatureProvider(dictionary: [inputName: pixelBuffer])
            let output = try model.prediction(from: input)
            let preferredOutputNames = ["final_emb_1", "embedding", "image_embedding"]
            let outputName = preferredOutputNames.first(where: { output.featureNames.contains($0) })
                ?? output.featureNames.first(where: { output.featureValue(for: $0)?.multiArrayValue?.count == 512 })
            guard let outputName,
                  let feature = output.featureValue(for: outputName)?.multiArrayValue,
                  feature.count == 512
            else { throw MobileCLIPError.invalidEmbedding }

            let embedding = (0..<feature.count).map { feature[$0].floatValue }
            guard let normalized = Self.normalized(embedding) else { throw MobileCLIPError.invalidEmbedding }
            return normalized
        }.value
    }

    private static func normalized(_ vector: [Float]) -> [Float]? {
        var squaredLength: Float = 0
        vDSP_svesq(vector, 1, &squaredLength, vDSP_Length(vector.count))
        let length = sqrt(squaredLength)
        guard length.isFinite, length > .leastNonzeroMagnitude else { return nil }
        return vector.map { $0 / length }
    }
}

/// Uses whole-image semantics only when detection found a single unresolved
/// region. It deliberately does not rewrite a multi-item YOLO result: scene
/// context is useful for empty/ambiguous scenes, but too coarse for instance
/// labels in clutter.
enum SceneSemanticCalibration {
    static func calibrate(_ items: [DetectedItem], in image: UIImage) async -> [DetectedItem] {
        guard items.count == 1,
              let item = items.first,
              item.name.hasPrefix("待确认"),
              extractor.isAvailable,
              vectorDB.isAvailable,
              let embedding = try? await extractor.extractImageFeature(from: image),
              let match = vectorDB.search(imageEmbedding: embedding, topK: 1).first,
              match.1 >= 0.16,
              let mapped = mappedItem(for: match.0)
        else { return items }

        var calibrated = item
        calibrated.name = mapped.name
        calibrated.category = mapped.category
        calibrated.suggestedZone = mapped.category.suggestedZone
        return [calibrated]
    }

    private static let extractor = MobileCLIPFeatureExtractor.shared
    private static let vectorDB = CategoryVectorDB.shared

    private static func mappedItem(for semanticName: String) -> (name: String, category: ItemCategory)? {
        switch semanticName {
        case "书本": return ("书本/资料", .books)
        case "电脑": return ("电脑设备", .electronics)
        case "键盘": return ("键盘", .electronics)
        case "手机": return ("手机", .electronics)
        case "文具": return ("文具", .stationery)
        case "衣物": return ("衣物", .clothes)
        case "工具": return ("工具", .tools)
        case "收纳盒": return ("收纳盒", .tools)
        case "餐具": return ("餐具", .tools)
        case "垃圾包装": return ("待清理杂物", .trash)
        default: return nil
        }
    }
}

/// Preserves YOLO masks and adds MobileCLIP category names when both MobileCLIP
/// assets are installed. Missing semantic assets intentionally use the current
/// YOLO result instead of inventing text embeddings.
struct SemanticRecognitionScanService: ScanService {
    private let detector: ScanService
    private let extractor: MobileCLIPFeatureExtractor
    private let textExtractor: MobileCLIPTextFeatureExtractor
    private let vectorDB: CategoryVectorDB

    init(
        detector: ScanService = YOLOSegmentationScanService(),
        extractor: MobileCLIPFeatureExtractor = .shared,
        textExtractor: MobileCLIPTextFeatureExtractor = .shared,
        vectorDB: CategoryVectorDB = .shared
    ) {
        self.detector = detector
        self.extractor = extractor
        self.textExtractor = textExtractor
        self.vectorDB = vectorDB
    }

    var backendStatus: RecognitionBackendStatus {
        RecognitionBackendStatus(
            imageEncoderAvailable: extractor.isAvailable,
            categoryVectorCount: vectorDB.categoryCount
        )
    }

    /// Spec-facing result API. The camera/AR views still consume DetectedItem
    /// because they also need the raster mask, while callers that need the
    /// v2.0 result contract can use this method directly.
    func recognizeObject(in image: UIImage) async throws -> [RecognitionResult] {
        try await scanWithMatches(image).map { item, matches in
            RecognitionResult(
                item: item,
                imageSize: image.size,
                alternatives: Array(matches.dropFirst()),
                source: matches.isEmpty ? .yolo : .mobileCLIP
            )
        }
    }

    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        try await scanWithMatches(image).map(\.0)
    }

    private func scanWithMatches(_ image: UIImage) async throws -> [(DetectedItem, [(String, Float)])] {
        let detectedItems = try await detector.scanImage(image)
        await MobileCLIPCategoryEmbeddingBuilder.ensureDefaultEmbeddings(
            vectorDB: vectorDB,
            extractor: textExtractor
        )
        guard extractor.isAvailable, vectorDB.isAvailable else {
            return detectedItems.map { ($0, []) }
        }

        let ordered = await withTaskGroup(of: (Int, DetectedItem, [(String, Float)]).self, returning: [(DetectedItem, [(String, Float)])].self) { group in
            for (index, item) in detectedItems.prefix(10).enumerated() {
                group.addTask {
                    let result = await semanticItem(for: item, in: image)
                    return (index, result.0, result.1)
                }
            }

            var results: [(Int, DetectedItem, [(String, Float)])] = []
            for await result in group { results.append(result) }
            return results
                .sorted { $0.0 < $1.0 }
                .map { ($0.1, $0.2) }
        }
        return ordered
    }

    private func semanticItem(for item: DetectedItem, in image: UIImage) async -> (DetectedItem, [(String, Float)]) {
        guard let hint = item.arHint else { return (item, []) }
        let box = DetectionBox(
            x: Float(hint.x), y: Float(hint.y), width: Float(hint.width), height: Float(hint.height), confidence: Float(item.confidence)
        )
        guard let cropped = image.cropped(to: box.toCGRect(imageSize: image.size)),
              let embedding = try? await extractor.extractImageFeature(from: cropped)
        else { return (item, []) }

        let matches = vectorDB.search(imageEmbedding: embedding, topK: 3)
        guard let topMatch = matches.first else { return (item, []) }

        var semanticItem = item
        semanticItem.name = topMatch.0
        semanticItem.confidence = Double(topMatch.1)
        semanticItem.category = Self.category(for: topMatch.0, fallback: item.category)
        semanticItem.suggestedZone = semanticItem.category.suggestedZone
        return (semanticItem, matches)
    }

    private static func category(for name: String, fallback: ItemCategory) -> ItemCategory {
        let lowercased = name.lowercased()
        if ["书", "本", "纸", "资料", "book", "paper"].contains(where: { lowercased.contains($0) }) { return .books }
        if ["电脑", "键盘", "鼠标", "手机", "平板", "线", "充电", "computer", "keyboard", "phone", "cable"].contains(where: { lowercased.contains($0) }) { return .electronics }
        if ["笔", "文具", "便签", "尺", "pen", "marker", "stationery"].contains(where: { lowercased.contains($0) }) { return .stationery }
        if ["衣", "鞋", "包", "shirt", "coat", "shoe"].contains(where: { lowercased.contains($0) }) { return .clothes }
        if ["玩具", "玩偶", "toy", "doll"].contains(where: { lowercased.contains($0) }) { return .toys }
        if ["垃圾", "包装", "trash", "waste"].contains(where: { lowercased.contains($0) }) { return .trash }
        if ["盒", "篮", "架", "抽屉", "收纳", "工具", "餐具", "容器", "box", "basket", "drawer", "tool", "utensil"].contains(where: { lowercased.contains($0) }) { return .tools }
        return fallback
    }
}

private extension UIImage {
    func cropped(to rect: CGRect) -> UIImage? {
        guard let normalizedCGImage = normalizedCGImageForRecognition else { return nil }
        let bounds = CGRect(origin: .zero, size: CGSize(width: normalizedCGImage.width, height: normalizedCGImage.height))
        let scaleX = CGFloat(normalizedCGImage.width) / max(size.width, 1)
        let scaleY = CGFloat(normalizedCGImage.height) / max(size.height, 1)
        let pixelRect = CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY, width: rect.width * scaleX, height: rect.height * scaleY)
            .integral
            .intersection(bounds)
        guard pixelRect.width >= 2, pixelRect.height >= 2,
              let cropped = normalizedCGImage.cropping(to: pixelRect)
        else { return nil }
        return UIImage(cgImage: cropped)
    }

    func centerCroppedPixelBuffer(size targetSize: CGSize) -> CVPixelBuffer? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let outputSize = CGSize(width: targetSize.width.rounded(), height: targetSize.height.rounded())
        let aspect = outputSize.width / outputSize.height
        let sourceAspect = size.width / max(size.height, 1)
        let cropRect: CGRect
        if sourceAspect > aspect {
            let width = size.height * aspect
            cropRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / aspect
            cropRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        }
        guard let cropped = cropped(to: cropRect) else { return nil }

        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, Int(outputSize.width), Int(outputSize.height), kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer
        else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(outputSize.width), height: Int(outputSize.height), bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        guard let croppedCGImage = cropped.cgImage else { return nil }
        context.draw(croppedCGImage, in: CGRect(origin: .zero, size: outputSize))
        return pixelBuffer
    }

    var normalizedCGImageForRecognition: CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }
}
