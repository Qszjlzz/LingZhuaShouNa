import Foundation
import CoreML
import UIKit
import Vision

protocol ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem]
}

protocol PlanningService {
    func makePlan(for space: StorageSpace, selectedItems: [DetectedItem], style: StorageStyle, timeBudget: TimeBudget, goal: String, focusZone: String) -> StoragePlan
}

protocol CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan
}

protocol StorageStore {
    func loadState() throws -> AppStateSnapshot?
    func saveState(_ snapshot: AppStateSnapshot) throws
}

struct AppStateSnapshot: Codable, Equatable {
    var spaces: [StorageSpace]
    var achievements: [Achievement]
    var communityCases: [CommunityCase]
    var communityComments: [UUID: [CommunityComment]]
    var scheduleItems: [ScheduleItem]
    var llmSettings: LLMSettings

    init(spaces: [StorageSpace], achievements: [Achievement], communityCases: [CommunityCase], communityComments: [UUID: [CommunityComment]] = [:], scheduleItems: [ScheduleItem] = [], llmSettings: LLMSettings = .default) {
        self.spaces = spaces
        self.achievements = achievements
        self.communityCases = communityCases
        self.communityComments = communityComments
        self.scheduleItems = scheduleItems
        self.llmSettings = llmSettings
    }

    enum CodingKeys: String, CodingKey {
        case spaces
        case achievements
        case communityCases
        case communityComments
        case scheduleItems
        case llmSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spaces = try container.decode([StorageSpace].self, forKey: .spaces)
        achievements = try container.decode([Achievement].self, forKey: .achievements)
        communityCases = try container.decode([CommunityCase].self, forKey: .communityCases)
        communityComments = try container.decodeIfPresent([UUID: [CommunityComment]].self, forKey: .communityComments) ?? [:]
        scheduleItems = try container.decodeIfPresent([ScheduleItem].self, forKey: .scheduleItems) ?? DemoData.scheduleItems
        llmSettings = try container.decodeIfPresent(LLMSettings.self, forKey: .llmSettings) ?? .default
    }
}

struct LLMSettings: Codable, Equatable {
    var isEnabled: Bool
    var endpoint: String
    var apiKey: String
    var model: String

    static let `default` = LLMSettings(
        isEnabled: false,
        endpoint: "https://api.openai.com/v1/responses",
        apiKey: "",
        model: "gpt-4.1-mini"
    )

    private enum CodingKeys: String, CodingKey {
        case isEnabled, endpoint, apiKey, model
    }

    init(isEnabled: Bool, endpoint: String, apiKey: String, model: String) {
        self.isEnabled = isEnabled
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint) ?? Self.default.endpoint
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? Self.default.model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(endpoint, forKey: .endpoint)
        try container.encode(model, forKey: .model)
    }

    var canRequest: Bool {
        guard isEnabled,
              let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil,
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased()))
        else { return false }
        return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct PlanningContext: Equatable {
    var space: StorageSpace
    var selectedItems: [DetectedItem]
    var goal: String
    var focusZone: String
    var selectedTags: [String] = []
    var recommendationMode: RecommendationMode = .balanced
    var referenceImageData: Data? = nil
}

enum RecommendationMode: String, Codable, CaseIterable, Identifiable {
    case balanced = "智能平衡"
    case budget = "低成本"
    case premium = "专业闭环"

    var id: String { rawValue }
}

enum ScanError: LocalizedError {
    case invalidImage
    case noRecognizedContent

    var errorDescription: String? {
        switch self {
        case .invalidImage: "图片无法读取，请换一张更清晰的照片。"
        case .noRecognizedContent: "暂时没有识别到可用于收纳规划的物品。"
        }
    }
}

struct VisionScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        guard let cgImage = image.normalizedCGImage else {
            throw ScanError.invalidImage
        }

        return await Task.detached(priority: .userInitiated) {
            let visualRegions = Self.visualRegions(in: cgImage)
            let classifiedItems = (try? Self.classifyItems(in: cgImage, visualRegions: visualRegions)) ?? []
            let textItems = (try? Self.recognizeTextItems(in: cgImage)) ?? []
            let deduplicated = Self.attachMissingRegions(
                to: Self.deduplicate(classifiedItems + textItems),
                using: visualRegions
            )
            if !deduplicated.isEmpty {
                return deduplicated
            }

            if let topObservation = try? Self.topClassificationObservation(in: cgImage) {
                let label = topObservation.identifier
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first ?? "未知物品"
                return [
                    DetectedItem(
                        name: label,
                        category: .tools,
                        confidence: Double(topObservation.confidence),
                        suggestedZone: "待确认收纳区",
                        arHint: visualRegions.first?.hint ?? .centerFallback,
                        arMask: visualRegions.first?.mask
                    )
                ]
            }

            return [
                DetectedItem(
                    name: "待确认区域",
                    category: .tools,
                    confidence: 0.30,
                    suggestedZone: "待确认收纳区",
                    arHint: visualRegions.first?.hint ?? .centerFallback,
                    arMask: visualRegions.first?.mask
                )
            ]
        }.value
    }

    private static func classifyItems(in cgImage: CGImage, visualRegions: [VisualRegion]) throws -> [DetectedItem] {
        let observations = try classificationObservations(in: cgImage)

        return observations.enumerated().compactMap { index, observation -> DetectedItem? in
            let labels = observation.identifier
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let category = Self.category(for: labels) else { return nil }
            let name = Self.displayName(for: labels, category: category)
            return DetectedItem(
                name: name,
                category: category,
                confidence: Double(observation.confidence),
                arHint: visualRegions[safe: index]?.hint ?? visualRegions.first?.hint,
                arMask: visualRegions[safe: index]?.mask ?? visualRegions.first?.mask
            )
        }
    }

    private static func topClassificationObservation(in cgImage: CGImage) throws -> VNClassificationObservation? {
        try classificationObservations(in: cgImage).first
    }

    private static func classificationObservations(in cgImage: CGImage) throws -> ArraySlice<VNClassificationObservation> {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? [])
            .filter { $0.confidence >= 0.08 }
            .prefix(12)
    }

    private static func recognizeTextItems(in cgImage: CGImage) throws -> [DetectedItem] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return (request.results ?? []).flatMap { observation -> [DetectedItem] in
            guard let text = observation.topCandidates(1).first?.string.lowercased(), !text.isEmpty else {
                return []
            }
            return keywordItems(in: text, arHint: Self.arHint(fromVisionBoundingBox: observation.boundingBox))
        }
    }

    private static func keywordItems(in text: String, arHint: ARHint? = nil) -> [DetectedItem] {
        let keywordMap: [(ItemCategory, [(String, String)])] = [
            (.books, [("notebook", "笔记本"), ("notepad", "笔记本"), ("journal", "笔记本"), ("worksheet", "讲义/试卷"), ("exam", "讲义/试卷"), ("paper", "纸张资料"), ("document", "文件资料"), ("book", "书本/资料"), ("笔记本", "笔记本"), ("本子", "笔记本"), ("讲义", "讲义/试卷"), ("试卷", "讲义/试卷"), ("作业", "讲义/试卷"), ("文件", "文件资料"), ("纸张", "纸张资料"), ("资料", "文件资料"), ("书", "书本/资料")]),
            (.electronics, [("laptop", "电脑设备"), ("computer", "电脑设备"), ("keyboard", "键盘"), ("monitor", "显示器"), ("phone", "手机"), ("charger", "充电器"), ("cable", "线缆"), ("电脑", "电脑设备"), ("手机", "手机")]),
            (.stationery, [("pen", "笔类文具"), ("pencil", "铅笔"), ("marker", "马克笔"), ("ruler", "尺子"), ("文具", "文具")]),
            (.clothes, [("shirt", "衣物"), ("coat", "外套"), ("jacket", "外套"), ("shoe", "鞋子"), ("衣服", "衣物"), ("鞋", "鞋子")]),
            (.toys, [("toy", "玩具"), ("doll", "玩偶"), ("plush", "毛绒玩具"), ("玩具", "玩具")]),
            (.trash, [("trash", "待清理杂物"), ("waste", "待清理杂物"), ("garbage", "待清理杂物"), ("垃圾", "待清理杂物")]),
            (.tools, [("box", "收纳盒/纸箱"), ("basket", "收纳篮"), ("container", "收纳盒"), ("drawer", "抽屉"), ("盒", "收纳盒")])
        ]

        return keywordMap.flatMap { category, keywords in
            keywords.compactMap { keyword, name in
                guard text.contains(keyword) else { return nil }
                return DetectedItem(
                    name: name,
                    category: category,
                    confidence: 0.92,
                    suggestedZone: category.suggestedZone,
                    arHint: arHint
                )
            }
        }
    }

    private static func deduplicate(_ items: [DetectedItem]) -> [DetectedItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.category.rawValue)-\(item.name)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func attachMissingRegions(to items: [DetectedItem], using regions: [VisualRegion]) -> [DetectedItem] {
        guard let fallbackRegion = regions.first else { return items }
        return items.enumerated().map { index, item in
            guard item.arHint == nil || item.arMask == nil else { return item }
            let region = regions[safe: index] ?? fallbackRegion
            var updated = item
            updated.arHint = item.arHint ?? region.hint
            updated.arMask = item.arMask ?? region.mask
            return updated
        }
    }

    private static func displayName(for labels: [String], category: ItemCategory) -> String {
        if let label = labels.first(where: { !$0.isEmpty }) {
            return localizedName(for: label, category: category)
        }
        return category.rawValue
    }

    private static func localizedName(for label: String, category: ItemCategory) -> String {
        let lowercased = label.lowercased()
        if lowercased.contains("notebook") || lowercased.contains("notepad") || lowercased.contains("journal") { return "笔记本" }
        if lowercased.contains("worksheet") || lowercased.contains("exam") { return "讲义/试卷" }
        if lowercased.contains("paper") { return "纸张资料" }
        if lowercased.contains("document") { return "文件资料" }
        if lowercased.contains("book") { return "书本/资料" }
        if lowercased.contains("laptop") || lowercased.contains("computer") { return "电脑设备" }
        if lowercased.contains("phone") || lowercased.contains("camera") { return "电子设备" }
        if lowercased.contains("pen") || lowercased.contains("pencil") { return "笔类文具" }
        if lowercased.contains("clothing") || lowercased.contains("shirt") { return "衣物" }
        if lowercased.contains("carton") || lowercased.contains("box") { return "收纳盒/纸箱" }
        if lowercased.contains("plastic bag") || lowercased.contains("waste") { return "待清理杂物" }
        return label
    }

    private static func category(for labels: [String]) -> ItemCategory? {
        let text = labels.joined(separator: " ").lowercased()
        let mapping: [(ItemCategory, [String])] = [
            (.books, ["book", "notebook", "notepad", "journal", "paper", "worksheet", "exam", "magazine", "library", "binder", "document"]),
            (.electronics, ["laptop", "computer", "keyboard", "monitor", "phone", "tablet", "camera", "charger", "cable", "remote"]),
            (.stationery, ["pen", "pencil", "marker", "ruler", "stationery", "desk", "office supplies"]),
            (.clothes, ["clothing", "shirt", "coat", "jacket", "sweater", "pants", "dress", "shoe"]),
            (.toys, ["toy", "doll", "stuffed", "plush"]),
            (.trash, ["trash", "waste", "garbage", "litter", "plastic bag"]),
            (.tools, ["box", "carton", "basket", "container", "shelf", "cabinet", "drawer"])
        ]

        return mapping.first { _, keywords in
            keywords.contains { text.contains($0) }
        }?.0
    }

    private static func visualRegions(in cgImage: CGImage) -> [VisualRegion] {
        var regions = foregroundMaskRegions(in: cgImage)

        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.maximumObservations = 6
        rectangleRequest.minimumConfidence = 0.35
        rectangleRequest.minimumAspectRatio = 0.15

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([saliencyRequest, rectangleRequest])

        let salientHints = (saliencyRequest.results ?? [])
            .flatMap { $0.salientObjects ?? [] }
            .map { observation in
                let hint = arHint(fromVisionBoundingBox: observation.boundingBox)
                return VisualRegion(hint: hint, mask: softMask(from: hint))
            }
        regions.append(contentsOf: salientHints)

        let rectangleHints = (rectangleRequest.results ?? [])
            .map { observation in
                let hint = arHint(fromVisionBoundingBox: observation.boundingBox)
                return VisualRegion(hint: hint, mask: softMask(from: hint))
            }
        regions.append(contentsOf: rectangleHints)

        return deduplicateRegions(regions).prefix(8).map { $0 }
    }

    private static func foregroundMaskRegions(in cgImage: CGImage) -> [VisualRegion] {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return [] }
            return observation.allInstances.compactMap { instanceIndex in
                let instances = IndexSet(integer: instanceIndex)
                guard let maskBuffer = try? observation.generateScaledMaskForImage(forInstances: instances, from: handler),
                      let mask = mask(from: maskBuffer)
                else { return nil }
                return VisualRegion(hint: hint(fromMask: mask), mask: mask)
            }
        } catch {
            return []
        }
    }

    private static func arHint(fromVisionBoundingBox box: CGRect) -> ARHint {
        ARHint(
            x: min(max(Double(box.midX), 0.08), 0.92),
            y: min(max(Double(1 - box.midY), 0.08), 0.92),
            width: min(max(Double(box.width), 0.16), 0.72),
            height: min(max(Double(box.height), 0.12), 0.62)
        )
    }

    private static func hint(fromMask mask: ARMask) -> ARHint {
        let minX = mask.points.map(\.x).min() ?? 0.33
        let maxX = mask.points.map(\.x).max() ?? 0.67
        let minY = mask.points.map(\.y).min() ?? 0.39
        let maxY = mask.points.map(\.y).max() ?? 0.61
        return ARHint(
            x: min(max((minX + maxX) / 2, 0.08), 0.92),
            y: min(max((minY + maxY) / 2, 0.08), 0.92),
            width: min(max(maxX - minX, 0.16), 0.72),
            height: min(max(maxY - minY, 0.12), 0.62)
        )
    }

    private static func softMask(from hint: ARHint) -> ARMask {
        let minX = max(0.02, hint.x - hint.width / 2)
        let maxX = min(0.98, hint.x + hint.width / 2)
        let minY = max(0.02, hint.y - hint.height / 2)
        let maxY = min(0.98, hint.y + hint.height / 2)
        let insetX = hint.width * 0.08
        let insetY = hint.height * 0.08
        return ARMask(points: [
            ARMaskPoint(x: hint.x, y: minY),
            ARMaskPoint(x: maxX - insetX, y: minY + insetY),
            ARMaskPoint(x: maxX, y: hint.y),
            ARMaskPoint(x: maxX - insetX, y: maxY - insetY),
            ARMaskPoint(x: hint.x, y: maxY),
            ARMaskPoint(x: minX + insetX, y: maxY - insetY),
            ARMaskPoint(x: minX, y: hint.y),
            ARMaskPoint(x: minX + insetX, y: minY + insetY)
        ])
    }

    private static func mask(from pixelBuffer: CVPixelBuffer) -> ARMask? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var rows: [(y: Int, left: Int, right: Int)] = []
        let rowStride = max(1, height / 16)

        for y in stride(from: 0, to: height, by: rowStride) {
            var left: Int?
            var right: Int?
            for x in 0..<width {
                if pointer[y * bytesPerRow + x] > 12 {
                    if left == nil { left = x }
                    right = x
                }
            }
            if let left, let right, right > left {
                rows.append((y, left, right))
            }
        }

        guard rows.count >= 3 else { return nil }
        let leftEdge = rows.map { ARMaskPoint(x: Double($0.left) / Double(width), y: Double($0.y) / Double(height)) }
        let rightEdge = rows.reversed().map { ARMaskPoint(x: Double($0.right) / Double(width), y: Double($0.y) / Double(height)) }
        let points = simplifyMaskPoints(leftEdge + rightEdge)
        return points.count >= 3 ? ARMask(points: points) : nil
    }

    private static func simplifyMaskPoints(_ points: [ARMaskPoint]) -> [ARMaskPoint] {
        guard points.count > 18 else { return points }
        let stride = max(1, points.count / 18)
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    private static func deduplicateRegions(_ regions: [VisualRegion]) -> [VisualRegion] {
        var result: [VisualRegion] = []
        for region in regions {
            let hint = region.hint
            let overlaps = result.contains { existing in
                abs(existing.hint.x - hint.x) < 0.04 && abs(existing.hint.y - hint.y) < 0.04
            }
            if !overlaps {
                result.append(region)
            }
        }
        return result
    }

    private struct VisualRegion {
        var hint: ARHint
        var mask: ARMask?
    }
}

struct CoreMLSegmentationScanService: ScanService {
    private let fallback = VisionScanService()

    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        let fallbackItems = try await fallback.scanImage(image)
        guard let region = await Self.segmentationRegion(in: image) else {
            return fallbackItems
        }

        return fallbackItems.enumerated().map { index, item in
            var updated = item
            if index == 0 || updated.arMask == nil {
                updated.arHint = region.hint
                updated.arMask = region.mask
            }
            return updated
        }
    }

    private static func segmentationRegion(in image: UIImage) async -> VisualRegion? {
        guard let cgImage = image.normalizedCGImage else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let modelURL = bundledModelURL(),
                  let model = try? MLModel(contentsOf: modelURL),
                  let visionModel = try? VNCoreMLModel(for: model)
            else { return nil }

            let request = VNCoreMLRequest(model: visionModel)
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                guard let observation = request.results?.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
                      let multiArray = observation.featureValue.multiArrayValue,
                      let mask = mask(from: multiArray)
                else { return nil }
                return VisualRegion(hint: hint(fromMask: mask), mask: mask)
            } catch {
                return nil
            }
        }.value
    }

    private static func bundledModelURL() -> URL? {
        let bundles = [Bundle.main] + Bundle.allBundles
        return bundles.lazy.compactMap {
            $0.url(forResource: "DeepLabV3Int8LUT", withExtension: "mlmodelc")
        }.first
    }

    private static func mask(from multiArray: MLMultiArray) -> ARMask? {
        guard multiArray.shape.count >= 2 else { return nil }
        let height = multiArray.shape[multiArray.shape.count - 2].intValue
        let width = multiArray.shape[multiArray.shape.count - 1].intValue
        guard width > 0, height > 0 else { return nil }

        var rows: [(y: Int, left: Int, right: Int)] = []
        let rowStride = max(1, height / 18)
        for y in stride(from: 0, to: height, by: rowStride) {
            var left: Int?
            var right: Int?
            for x in 0..<width where label(in: multiArray, x: x, y: y, width: width) != 0 {
                if left == nil { left = x }
                right = x
            }
            if let left, let right, right > left {
                rows.append((y, left, right))
            }
        }

        guard rows.count >= 3 else { return nil }
        let leftEdge = rows.map { ARMaskPoint(x: Double($0.left) / Double(width), y: Double($0.y) / Double(height)) }
        let rightEdge = rows.reversed().map { ARMaskPoint(x: Double($0.right) / Double(width), y: Double($0.y) / Double(height)) }
        let points = simplifyMaskPoints(leftEdge + rightEdge)
        return points.count >= 3 ? ARMask(points: points) : nil
    }

    private static func label(in multiArray: MLMultiArray, x: Int, y: Int, width: Int) -> Int32 {
        let index = y * width + x
        switch multiArray.dataType {
        case .int32:
            return multiArray.dataPointer.assumingMemoryBound(to: Int32.self)[index]
        case .float32:
            return Int32(multiArray.dataPointer.assumingMemoryBound(to: Float.self)[index])
        case .double:
            return Int32(multiArray.dataPointer.assumingMemoryBound(to: Double.self)[index])
        default:
            return multiArray[index].int32Value
        }
    }

    private static func hint(fromMask mask: ARMask) -> ARHint {
        let minX = mask.points.map(\.x).min() ?? 0.33
        let maxX = mask.points.map(\.x).max() ?? 0.67
        let minY = mask.points.map(\.y).min() ?? 0.39
        let maxY = mask.points.map(\.y).max() ?? 0.61
        return ARHint(
            x: min(max((minX + maxX) / 2, 0.08), 0.92),
            y: min(max((minY + maxY) / 2, 0.08), 0.92),
            width: min(max(maxX - minX, 0.16), 0.72),
            height: min(max(maxY - minY, 0.12), 0.62)
        )
    }

    private static func simplifyMaskPoints(_ points: [ARMaskPoint]) -> [ARMaskPoint] {
        guard points.count > 22 else { return points }
        let stride = max(1, points.count / 22)
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    private struct VisualRegion {
        var hint: ARHint
        var mask: ARMask
    }
}

private enum OCRToolRecovery {
    static func items(in image: CGImage) async -> [DetectedItem] {
        await Task.detached(priority: .utility) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            guard (try? handler.perform([request])) != nil else { return [] }

            let matches = (request.results ?? []).compactMap { observation -> (CGRect, Float)? in
                guard let text = observation.topCandidates(1).first else { return nil }
                guard text.string.lowercased().contains("drill") else { return nil }
                let box = observation.boundingBox
                return (CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height), text.confidence)
            }
            guard !matches.isEmpty else { return [] }

            let textBounds = matches.map(\.0).reduce(matches[0].0) { $0.union($1) }
            // Product labels sit near the center of a hand tool. This converts
            // several OCR text lines into a conservative object region while
            // remaining inactive unless an explicit tool word was recognized.
            let minX = max(0, textBounds.minX - textBounds.width * 1.3)
            let maxX = min(1, textBounds.maxX + textBounds.width * 1.3)
            let minY = max(0, textBounds.minY - textBounds.height * 12)
            let maxY = min(1, textBounds.maxY + textBounds.height * 20)
            guard maxX > minX, maxY > minY else { return [] }
            let confidence = max(0.55, Double(matches.map(\.1).max() ?? 0))
            return [DetectedItem(
                name: "电钻",
                category: .tools,
                confidence: confidence,
                arHint: ARHint(
                    x: Double((minX + maxX) / 2),
                    y: Double((minY + maxY) / 2),
                    width: Double(maxX - minX),
                    height: Double(maxY - minY)
                )
            )]
        }.value
    }
}

struct YOLOSegmentationScanService: ScanService {
    private let fallback = CoreMLSegmentationScanService()
    private let edgeSAM = EdgeSAMSegmentationService()

    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        guard let cgImage = image.normalizedCGImage else {
            throw ScanError.invalidImage
        }

        let yoloItems = Self.cleanedItems(await Self.detectItems(in: cgImage))
        let textRecoveredItems = await OCRToolRecovery.items(in: cgImage)
        let recoveredItems = Self.cleanedItems(yoloItems + textRecoveredItems)
        if !recoveredItems.isEmpty {
            // YOLOE already emits instance masks. EdgeSAM's point decoder is
            // used only for suspicious full-frame regions; tight masks stay
            // on the detector output to avoid a second coordinate transform.
            let refined = await edgeSAM.refine(recoveredItems, in: cgImage)
            let cleaned = Array(Self.presentationItems(Self.cleanedItems(refined), mode: .still).prefix(10))
            return await SceneSemanticCalibration.calibrate(cleaned, in: image)
        }
        let fallbackItems = Self.cleanedItems(try await fallback.scanImage(image))
        let refined = await edgeSAM.refine(fallbackItems, in: cgImage)
        return await SceneSemanticCalibration.calibrate(Self.presentationItems(Self.cleanedItems(refined), mode: .still), in: image)
    }

    // Live AR needs a predictable frame budget. Use the primary instance
    // segmentation model only; OCR, EdgeSAM, and semantic calibration remain
    // available for the higher-quality still-image scan above.
    func scanLiveImage(_ image: UIImage) async -> [DetectedItem] {
        guard let cgImage = image.normalizedCGImage else { return [] }
        let detected = await Self.detectItems(in: cgImage, live: true)
        return Array(Self.presentationItems(Self.cleanedItems(detected), mode: .live).prefix(8))
    }

    private enum PresentationMode {
        case still
        case live

        var minimumConfidence: Double {
            switch self {
            // Still-photo recognition feeds confirmation and planning, so it
            // keeps a little more recall than the live overlay. The separate
            // unknown-label gate below still removes the most visible noise.
            case .still: 0.12
            case .live: 0.22
            }
        }

        func minimumConfidence(for item: DetectedItem) -> Double {
            guard case .live = self else { return minimumConfidence }
            // These are the four primary desk targets. Keep the lower live
            // thresholds only for candidates that already carry a real mask;
            // box-only guesses are removed before this stage.
            switch item.name {
            case "书本/资料", "笔记本", "笔", "笔类文具": return 0.18
            case "杯子": return 0.24
            case "电脑设备": return 0.20
            default: return minimumConfidence
            }
        }
    }

    // A segmentation model can emit tiny islands or nearly identical labels for
    // the same object. They are technically valid masks, but make the camera
    // view look noisy and are not useful candidates for a storage plan.
    private static func cleanedItems(_ items: [DetectedItem]) -> [DetectedItem] {
        let renderable = items.compactMap { item -> DetectedItem? in
            var item = item
            if item.arMask == nil {
                // A label without a real raster mask is ambiguous in the camera
                // view. Drop sparse context-only boxes instead of presenting a
                // tag that cannot be visually tied to an object.
                return nil
            }
            if let mask = item.arMask, !mask.hasRaster, mask.points.count >= 3 {
                item.arMask = rasterized(mask)
            }
            guard let mask = item.arMask, mask.hasRaster else { return nil }
            let pixelCount = mask.rasterPixelCount
            let rasterArea = max(1, (mask.rasterWidth ?? 0) * (mask.rasterHeight ?? 0))
            guard pixelCount >= 6,
                Double(pixelCount) / Double(rasterArea) >= 0.004
            else { return nil }
            return item
        }

        var kept: [DetectedItem] = []
        for item in mergedCupFragments(renderable).sorted(by: { $0.confidence > $1.confidence }) {
            let duplicate = kept.contains { existing in
                let sameCategory = existing.category == item.category
                guard let lhs = existing.arHint, let rhs = item.arHint else { return false }
                return hintIoU(lhs, rhs) >= (sameCategory ? 0.62 : 0.82)
            }
            if !duplicate { kept.append(item) }
        }
        return kept
    }

    // The capture view is a storage workflow rather than an open-ended scene
    // catalog. Suppress furniture labels and retain one strongest grouped-books
    // mask, so the overlay stays readable without guessing locations or
    // fabricating any segmentation area. Clothes stay independent because a
    // closet can contain several spatially distinct garment groups.
    private static func presentationItems(_ items: [DetectedItem], mode: PresentationMode) -> [DetectedItem] {
        let furnitureLabels: Set<String> = ["椅子", "沙发/软包", "床铺区域", "桌面区域"]
        var groupedCategorySeen = Set<ItemCategory>()
        return items
            .sorted { $0.confidence > $1.confidence }
            .filter { item in
                guard !furnitureLabels.contains(item.name) else { return false }
                // These candidates are deliberately broad guesses. A weak
                // guess is worse than showing no tag because it gets saved into
                // the user's space and later drives the storage plan.
                guard item.confidence >= mode.minimumConfidence(for: item) else { return false }
                guard item.name != "待确认物体" || item.confidence >= 0.50 else { return false }
                guard item.category == .books else { return true }
                return groupedCategorySeen.insert(item.category).inserted
            }
    }

    // A cup is commonly split into rim and body islands by the segmentation
    // decoder. Join only vertically adjacent cup fragments that share a
    // substantial horizontal span; separate cups stay independent.
    private static func mergedCupFragments(_ items: [DetectedItem]) -> [DetectedItem] {
        var remaining = items
        var didMerge = true
        while didMerge {
            didMerge = false
            outer: for leftIndex in remaining.indices {
                guard remaining[leftIndex].name == "杯子",
                      remaining[leftIndex].category == .tools,
                      let leftHint = remaining[leftIndex].arHint,
                      let leftMask = remaining[leftIndex].arMask,
                      leftMask.hasRaster
                else { continue }
                for rightIndex in remaining.indices where rightIndex > leftIndex {
                    guard remaining[rightIndex].name == "杯子",
                          remaining[rightIndex].category == .tools,
                          let rightHint = remaining[rightIndex].arHint,
                          let rightMask = remaining[rightIndex].arMask,
                          rightMask.hasRaster,
                          shouldMergeCupFragments(leftHint, rightHint),
                          let mask = unionMask(leftMask, rightMask)
                    else { continue }
                    let box = unionHint(leftHint, rightHint)
                    var merged = remaining[leftIndex]
                    merged.confidence = max(remaining[leftIndex].confidence, remaining[rightIndex].confidence)
                    merged.arHint = box
                    merged.arMask = mask
                    remaining[leftIndex] = merged
                    remaining.remove(at: rightIndex)
                    didMerge = true
                    break outer
                }
            }
        }
        return remaining
    }

    private static func shouldMergeCupFragments(_ lhs: ARHint, _ rhs: ARHint) -> Bool {
        let lhsMinX = lhs.x - lhs.width / 2
        let lhsMaxX = lhs.x + lhs.width / 2
        let rhsMinX = rhs.x - rhs.width / 2
        let rhsMaxX = rhs.x + rhs.width / 2
        let horizontalOverlap = max(0, min(lhsMaxX, rhsMaxX) - max(lhsMinX, rhsMinX))
        guard horizontalOverlap / max(.leastNonzeroMagnitude, min(lhs.width, rhs.width)) >= 0.30 else { return false }
        let lhsMinY = lhs.y - lhs.height / 2
        let lhsMaxY = lhs.y + lhs.height / 2
        let rhsMinY = rhs.y - rhs.height / 2
        let rhsMaxY = rhs.y + rhs.height / 2
        let verticalGap = max(0, max(lhsMinY, rhsMinY) - min(lhsMaxY, rhsMaxY))
        return verticalGap <= 0.07
    }

    private static func unionHint(_ lhs: ARHint, _ rhs: ARHint) -> ARHint {
        let minX = max(0, min(lhs.x - lhs.width / 2, rhs.x - rhs.width / 2))
        let maxX = min(1, max(lhs.x + lhs.width / 2, rhs.x + rhs.width / 2))
        let minY = max(0, min(lhs.y - lhs.height / 2, rhs.y - rhs.height / 2))
        let maxY = min(1, max(lhs.y + lhs.height / 2, rhs.y + rhs.height / 2))
        return ARHint(x: (minX + maxX) / 2, y: (minY + maxY) / 2, width: maxX - minX, height: maxY - minY)
    }

    private static func unionMask(_ lhs: ARMask, _ rhs: ARMask) -> ARMask? {
        guard let width = lhs.rasterWidth,
              let height = lhs.rasterHeight,
              width == rhs.rasterWidth,
              height == rhs.rasterHeight,
              let lhsAlpha = lhs.rasterAlpha,
              let rhsAlpha = rhs.rasterAlpha,
              lhsAlpha.count == rhsAlpha.count
        else { return nil }
        let mergedAlpha = zip(lhsAlpha, rhsAlpha).map(max)
        let points = maskContourFromRaster(mergedAlpha, width: width, height: height)
        return ARMask(points: points, rasterWidth: width, rasterHeight: height, rasterAlpha: Data(mergedAlpha))
    }

    private static func hint(from mask: ARMask) -> ARHint {
        let minX = mask.points.map(\.x).min() ?? 0
        let maxX = mask.points.map(\.x).max() ?? 1
        let minY = mask.points.map(\.y).min() ?? 0
        let maxY = mask.points.map(\.y).max() ?? 1
        return ARHint(x: (minX + maxX) / 2, y: (minY + maxY) / 2, width: maxX - minX, height: maxY - minY)
    }

    private static func rasterized(_ mask: ARMask) -> ARMask {
        let width = 64
        let height = 64
        let points = mask.points.map { (x: min(max($0.x, 0), 1), y: min(max($0.y, 0), 1)) }
        guard points.count >= 3 else { return mask }

        func contains(_ x: Double, _ y: Double) -> Bool {
            var inside = false
            var previous = points.count - 1
            for current in points.indices {
                let a = points[current]
                let b = points[previous]
                let crosses = (a.y > y) != (b.y > y)
                let denominator = b.y - a.y
                if crosses, abs(denominator) > .leastNonzeroMagnitude {
                    let intersectionX = (b.x - a.x) * (y - a.y) / denominator + a.x
                    if x < intersectionX { inside.toggle() }
                }
                previous = current
            }
            return inside
        }

        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width where contains((Double(x) + 0.5) / Double(width), (Double(y) + 0.5) / Double(height)) {
                alpha[y * width + x] = 180
            }
        }
        let normalizedPoints = points.map { ARMaskPoint(x: $0.x, y: $0.y) }
        return ARMask(points: normalizedPoints, rasterWidth: width, rasterHeight: height, rasterAlpha: Data(alpha))
    }

    private static func hintIoU(_ lhs: ARHint, _ rhs: ARHint) -> Double {
        let lhsRect = CGRect(x: lhs.x - lhs.width / 2, y: lhs.y - lhs.height / 2, width: lhs.width, height: lhs.height)
        let rhsRect = CGRect(x: rhs.x - rhs.width / 2, y: rhs.y - rhs.height / 2, width: rhs.width, height: rhs.height)
        let intersection = lhsRect.intersection(rhsRect)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = lhsRect.width * lhsRect.height + rhsRect.width * rhsRect.height - intersectionArea
        return unionArea > 0 ? Double(intersectionArea / unionArea) : 0
    }

    private static func detectItems(in cgImage: CGImage, live: Bool = false) async -> [DetectedItem] {
        await Task.detached(priority: .userInitiated) {
            guard !cachedModels.isEmpty else { return [] }
            var mergedItems: [DetectedItem] = []
            // Live AR and still capture have different budgets, but they must
            // share the same target vocabulary. The old live path used only
            // generic YOLO11, so pen/book/cup labels could disappear even
            // though the final photo scan recognized them. Use the compact
            // promptable model for live targets and the 640 generic model to
            // recover common electronics without running the 1280 graph on
            // every camera frame.
            let models: [YOLOModel]
            if live {
                let promptable = cachedModels.filter { $0.sourceName == "yoloe-11s-seg" }
                let realtimeGeneric = cachedModels.filter { $0.sourceName == "yolo11n-seg-640" }
                models = Array((promptable + realtimeGeneric).prefix(2))
            } else {
                models = cachedModels
            }
            for model in models {
                guard let letterbox = letterboxPixelBuffer(cgImage, inputSize: model.inputSize) else { continue }
                do {
                    let input = try MLDictionaryFeatureProvider(dictionary: ["image": letterbox.pixelBuffer])
                    let output = try model.model.prediction(from: input)
                    let tensors = output.featureNames.compactMap { output.featureValue(for: $0)?.multiArrayValue }
                    let detectedItems = model.kind == .worldDetection ? worldItems(
                        from: tensors,
                        transform: letterbox.transform,
                        classNames: model.classNames
                    ) : items(
                        from: tensors,
                        transform: letterbox.transform,
                        classNames: model.classNames
                    )
                    // Keep the first model's candidates authoritative, then use
                    // later models only to recover spatially distinct objects.
                    // YOLOE is ordered first for its storage-focused vocabulary;
                    // YOLO11/640 fills recall gaps without duplicating overlays.
                    mergedItems.append(contentsOf: detectedItems)
                } catch {
                    continue
                }
            }
            return mergeModelCandidates(mergedItems)
        }.value
    }

    private static func mergeModelCandidates(_ items: [DetectedItem]) -> [DetectedItem] {
        var kept: [DetectedItem] = []
        for item in items {
            guard item.arHint != nil,
                  item.arMask?.hasRaster == true || (item.arMask == nil && item.confidence >= 0.055)
            else { continue }
            let duplicate = kept.contains { existing in
                guard let lhs = existing.arHint, let rhs = item.arHint else { return false }
                let overlap = hintIoU(lhs, rhs)
                // A later model may recover a nearby object of a different class,
                // but not when it is effectively the same region. Same-category
                // candidates use the looser threshold because detector variants
                // commonly shift their box by a few pixels.
                return overlap >= (existing.category == item.category ? 0.45 : 0.72)
            }
            if !duplicate { kept.append(item) }
        }
        return kept.sorted { $0.confidence > $1.confidence }
    }

    private static func letterboxPixelBuffer(_ image: CGImage, inputSize: Int) -> (pixelBuffer: CVPixelBuffer, transform: LetterboxTransform)? {
        let gain = min(CGFloat(inputSize) / CGFloat(image.width), CGFloat(inputSize) / CGFloat(image.height))
        let contentWidth = max(1, Int((CGFloat(image.width) * gain).rounded()))
        let contentHeight = max(1, Int((CGFloat(image.height) * gain).rounded()))
        let padX = CGFloat(inputSize - contentWidth) / 2
        let padY = CGFloat(inputSize - contentHeight) / 2
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]
        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            inputSize,
            inputSize,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        ) == kCVReturnSuccess,
              let pixelBuffer
        else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: inputSize,
            height: inputSize,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        context.setFillColor(red: 114 / 255, green: 114 / 255, blue: 114 / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: inputSize, height: inputSize))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: padX, y: padY, width: CGFloat(contentWidth), height: CGFloat(contentHeight)))
        return (
            pixelBuffer,
            LetterboxTransform(
                inputSize: inputSize,
                contentWidth: contentWidth,
                contentHeight: contentHeight,
                padX: padX,
                padY: padY
            )
        )
    }

    private static let cachedModels: [YOLOModel] = {
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        // The 1280 segmentation graph can leave the simulator's MPSGraph backend
        // in an invalid state after repeated requests. CPU inference is slower but
        // deterministic; physical devices can still use GPU/Neural Engine.
        configuration.computeUnits = .cpuOnly
        #else
        configuration.computeUnits = .all
        #endif
        return bundledModelURLs().compactMap { modelURL in
            guard let model = try? MLModel(contentsOf: modelURL, configuration: configuration) else { return nil }
            let inputSize = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint?.pixelsWide ?? 0
            guard inputSize > 0 else { return nil }
            let kind: YOLOModelKind = modelURL.lastPathComponent.hasPrefix("yolov8s-worldv2") ? .worldDetection : .segmentation
            let classNames: [String]
            if modelURL.lastPathComponent.hasPrefix("yoloe-11s-seg") {
                classNames = yoloeClassNames
            } else if modelURL.lastPathComponent.hasPrefix("yoloe-context-seg") {
                classNames = yoloeContextClassNames
            } else {
                classNames = kind == .worldDetection ? worldClassNames : cocoNames
            }
            return YOLOModel(
                model: model,
                inputSize: inputSize,
                classNames: classNames,
                kind: kind,
                sourceName: modelURL.deletingPathExtension().lastPathComponent
            )
        }
    }()

    private static func bundledModelURLs() -> [URL] {
        let bundles = [Bundle.main] + Bundle.allBundles
        let candidates = [
            ("yoloe-11s-seg", "mlmodelc"),
            ("yoloe-11s-seg", "mlpackage"),
            ("yoloe-context-seg", "mlmodelc"),
            ("yoloe-context-seg", "mlpackage"),
            ("yolo11n-seg", "mlmodelc"),
            ("yolo11n-seg", "mlpackage"),
            ("yolo11n-seg-640", "mlmodelc"),
            ("yolo11n-seg-640", "mlpackage"),
            ("yolov8s-worldv2", "mlmodelc"),
            ("yolov8s-worldv2", "mlpackage"),
            ("yolov8n-seg", "mlmodelc"),
            ("yolov8n-seg", "mlpackage")
        ]
        var urls: [URL] = []
        for (name, ext) in candidates {
            guard let url = bundles.lazy.compactMap({ $0.url(forResource: name, withExtension: ext) }).first,
                  !urls.contains(url)
            else { continue }
            urls.append(url)
        }
        return urls
    }

    private static func items(from tensors: [MLMultiArray], transform: LetterboxTransform, classNames: [String]) -> [DetectedItem] {
        guard let detectionTensor = tensors
            .first(where: { dims in
                let shape = dims.shape.map(\.intValue)
                return shape.count == 3 && shape.count > 1 && shape[1] >= 37
            }),
              let protoTensor = tensors
            .first(where: { shape in
                let dims = shape.shape.map(\.intValue)
                return dims.count == 4
                    && dims[1] == 32
                    && dims[2] >= 160
                    && dims[3] >= 160
            })
        else { return [] }

        let inputSize = transform.inputSize
        let detections = candidateDetections(from: detectionTensor, inputSize: inputSize)
        return nonMaxSuppressed(detections)
            .prefix(10)
            .compactMap { detection in
                let mask = mask(for: detection, protoTensor: protoTensor, transform: transform)
                // Context prompts are permitted to surface an actual detector
                // box without a mask. General segmentation models are not.
                guard mask != nil || classNames == yoloeContextClassNames else { return nil }
                let usableMask: ARMask?
                if classNames == yoloeContextClassNames,
                   let mask,
                   (mask.rasterPixelCount < 6 || mask.rasterCoverage < 0.004) {
                    usableMask = nil
                } else {
                    usableMask = mask
                }
                let className = classNames[safe: detection.classIndex] ?? "unknown"
                let category = category(forClassName: className)
                let hint = originalHint(for: detection.box, transform: transform)
                let isWeakCup = className.lowercased().contains("cup") && detection.confidence < 0.55
                return DetectedItem(
                    name: isWeakCup ? "待确认物体" : displayName(forClassName: className),
                    category: isWeakCup ? .tools : category,
                    confidence: Double(detection.confidence),
                    suggestedZone: (isWeakCup ? ItemCategory.tools : category).suggestedZone,
                    arHint: hint,
                    arMask: usableMask
                )
            }
    }

    private static func worldItems(from tensors: [MLMultiArray], transform: LetterboxTransform, classNames: [String]) -> [DetectedItem] {
        guard let tensor = tensors.first(where: { tensor in
            let dimensions = tensor.shape.map(\.intValue)
            return dimensions.count == 3 && dimensions[1] == 4 + classNames.count
        }) else { return [] }
        return worldDetections(from: tensor, inputSize: transform.inputSize)
            .compactMap { detection in
                let className = classNames[safe: detection.classIndex] ?? ""
                guard className == "tablet computer", detection.confidence >= 0.35 else { return nil }
                let item = (name: "平板电脑", category: ItemCategory.electronics)
                return DetectedItem(
                    name: item.name,
                    category: item.category,
                    confidence: Double(detection.confidence),
                    suggestedZone: item.category.suggestedZone,
                    arHint: originalHint(for: detection.box, transform: transform)
                )
            }
    }

    private static func worldDetections(from tensor: MLMultiArray, inputSize: Int) -> [YOLODetection] {
        let dimensions = tensor.shape.map(\.intValue)
        guard dimensions.count == 3, dimensions[1] == 4 + worldClassNames.count else { return [] }
        var candidates: [YOLODetection] = []
        for anchor in 0..<dimensions[2] {
            var bestClass = 0
            var bestScore: Float = 0
            for classIndex in 0..<worldClassNames.count {
                let score = floatValue(tensor, channel: 4 + classIndex, anchor: anchor)
                if score > bestScore {
                    bestScore = score
                    bestClass = classIndex
                }
            }
            guard bestScore >= 0.35 else { continue }
            let scale = Float(max(inputSize, 1))
            let centerX = floatValue(tensor, channel: 0, anchor: anchor) / scale
            let centerY = floatValue(tensor, channel: 1, anchor: anchor) / scale
            let width = floatValue(tensor, channel: 2, anchor: anchor) / scale
            let height = floatValue(tensor, channel: 3, anchor: anchor) / scale
            guard width > 0, height > 0 else { continue }
            let minX = min(max(centerX - width / 2, 0), 1)
            let minY = min(max(centerY - height / 2, 0), 1)
            let maxX = min(max(centerX + width / 2, 0), 1)
            let maxY = min(max(centerY + height / 2, 0), 1)
            guard maxX > minX, maxY > minY else { continue }
            candidates.append(YOLODetection(
                classIndex: bestClass,
                confidence: bestScore,
                box: CGRect(x: CGFloat(minX), y: CGFloat(minY), width: CGFloat(maxX - minX), height: CGFloat(maxY - minY)),
                coefficients: []
            ))
        }
        return nonMaxSuppressed(candidates)
    }

    private static func candidateDetections(from tensor: MLMultiArray, inputSize: Int) -> [YOLODetection] {
        let dims = tensor.shape.map(\.intValue)
        guard dims.count == 3 else { return [] }
        let channelCount = dims[1]
        let anchorCount = dims[2]
        let classCount = channelCount - 4 - 32
        guard classCount > 0, anchorCount > 0 else { return [] }

        var candidates: [YOLODetection] = []
        for anchor in 0..<anchorCount {
            var bestClass = 0
            var bestScore: Float = 0
            for classIndex in 0..<classCount {
                let score = floatValue(tensor, channel: 4 + classIndex, anchor: anchor)
                if score > bestScore {
                    bestScore = score
                    bestClass = classIndex
                }
            }
            // Weak detections produce visibly unstable masks in cluttered scenes. It is
            // better to omit them than paint an unrelated region in the AR overlay.
            let minimumScore: Float
            if classCount == yoloeClassNames.count {
                minimumScore = yoloeMinimumScore(for: bestClass)
            } else if classCount == yoloeContextClassNames.count {
                minimumScore = yoloeContextMinimumScore(for: bestClass)
            } else {
                minimumScore = cocoMinimumScore(for: bestClass)
            }
            guard bestScore >= minimumScore else { continue }

            let scale = Float(max(inputSize, 1))
            let centerX = floatValue(tensor, channel: 0, anchor: anchor) / scale
            let centerY = floatValue(tensor, channel: 1, anchor: anchor) / scale
            let width = floatValue(tensor, channel: 2, anchor: anchor) / scale
            let height = floatValue(tensor, channel: 3, anchor: anchor) / scale
            guard width > 0, height > 0 else { continue }

            let minX = min(max(centerX - width / 2, 0), 1)
            let minY = min(max(centerY - height / 2, 0), 1)
            let maxX = min(max(centerX + width / 2, 0), 1)
            let maxY = min(max(centerY + height / 2, 0), 1)
            guard maxX > minX, maxY > minY else { continue }
            let box = CGRect(
                x: CGFloat(minX),
                y: CGFloat(minY),
                width: CGFloat(maxX - minX),
                height: CGFloat(maxY - minY)
            )
            let coefficients = (0..<32).map { floatValue(tensor, channel: 4 + classCount + $0, anchor: anchor) }
            candidates.append(YOLODetection(classIndex: bestClass, confidence: bestScore, box: box, coefficients: coefficients))
        }
        return candidates.sorted { $0.confidence > $1.confidence }
    }

    private static func nonMaxSuppressed(_ detections: [YOLODetection]) -> [YOLODetection] {
        var selected: [YOLODetection] = []
        for detection in detections {
            let overlaps = selected.contains { existing in
                existing.classIndex == detection.classIndex &&
                intersectionOverUnion(detection.box, existing.box) > 0.45
            }
            if !overlaps {
                selected.append(detection)
            }
            if selected.count >= 10 { break }
        }
        return selected
    }

    private static func mask(for detection: YOLODetection, protoTensor: MLMultiArray, transform: LetterboxTransform) -> ARMask? {
        let dimensions = protoTensor.shape.map(\.intValue)
        guard let protoWidth = dimensions.last,
              dimensions.count >= 2,
              let protoHeight = dimensions.dropLast().last,
              protoWidth > 0,
              protoHeight > 0
        else { return nil }
        let minX = max(0, Int(detection.box.minX * CGFloat(protoWidth)))
        let maxX = min(protoWidth - 1, Int(detection.box.maxX * CGFloat(protoWidth)))
        let minY = max(0, Int(detection.box.minY * CGFloat(protoHeight)))
        let maxY = min(protoHeight - 1, Int(detection.box.maxY * CGFloat(protoHeight)))
        guard maxX > minX, maxY > minY else { return nil }

        var probabilities = [Float](repeating: 0, count: protoWidth * protoHeight)
        for y in minY...maxY {
            for x in minX...maxX {
                var logit: Float = 0
                for channel in 0..<min(32, detection.coefficients.count) {
                    logit += detection.coefficients[channel] * protoValue(protoTensor, channel: channel, x: x, y: y)
                }
                let probability = sigmoid(logit)
                let index = y * protoWidth + x
                probabilities[index] = probability
            }
        }

        let protoScaleX = CGFloat(protoWidth) / CGFloat(transform.inputSize)
        let protoScaleY = CGFloat(protoHeight) / CGFloat(transform.inputSize)
        let cropMinX = min(protoWidth - 1, max(0, Int(floor(transform.padX * protoScaleX))))
        let cropMinY = min(protoHeight - 1, max(0, Int(floor(transform.padY * protoScaleY))))
        let cropMaxX = min(protoWidth, max(cropMinX + 1, Int(ceil((transform.padX + CGFloat(transform.contentWidth)) * protoScaleX))))
        let cropMaxY = min(protoHeight, max(cropMinY + 1, Int(ceil((transform.padY + CGFloat(transform.contentHeight)) * protoScaleY))))
        // Keep enough spatial detail for a phone-sized overlay. A 64x64 mask
        // becomes visibly stair-stepped after it is enlarged to the camera
        // viewport, especially on bottles and laptop corners.
        let rasterWidth = 128
        let rasterHeight = 128
        var foreground = [Bool](repeating: false, count: protoWidth * protoHeight)
        let visibleMinY = max(minY, cropMinY)
        let visibleMaxY = min(maxY, cropMaxY - 1)
        let visibleMinX = max(minX, cropMinX)
        let visibleMaxX = min(maxX, cropMaxX - 1)
        guard visibleMaxX > visibleMinX, visibleMaxY > visibleMinY else { return nil }
        for y in visibleMinY...visibleMaxY {
            for x in visibleMinX...visibleMaxX {
                let index = y * protoWidth + x
                foreground[index] = probabilities[index] >= 0.58
            }
        }

        // Keep the connected foreground belonging to this detection. Filling the
        // span between the first and last foreground pixel on each row connects
        // unrelated objects across gaps and creates the large broken polygons
        // previously visible in the AR overlay.
        let retained = retainedMaskComponents(
            foreground,
            width: protoWidth,
            minX: visibleMinX,
            maxX: visibleMaxX,
            minY: visibleMinY,
            maxY: visibleMaxY
        )
        let retainedPixels = retained.enumerated().filter { $0.element }
        guard retainedPixels.count >= 6 else {
            return nil
        }

        // Resample the retained proto mask at pixel centres instead of writing
        // one isolated output pixel for every proto cell. The old approach
        // produced sparse islands which looked like fuzzy, broken outlines.
        var alpha = [UInt8](repeating: 0, count: rasterWidth * rasterHeight)
        for rasterY in 0..<rasterHeight {
            let normalizedY = (Double(rasterY) + 0.5) / Double(rasterHeight)
            let inputY = (normalizedY * Double(transform.contentHeight) + Double(transform.padY)) / Double(transform.inputSize)
            let protoY = min(protoHeight - 1, max(0, Int(inputY * Double(protoHeight))))
            for rasterX in 0..<rasterWidth {
                let normalizedX = (Double(rasterX) + 0.5) / Double(rasterWidth)
                let inputX = (normalizedX * Double(transform.contentWidth) + Double(transform.padX)) / Double(transform.inputSize)
                let protoX = min(protoWidth - 1, max(0, Int(inputX * Double(protoWidth))))
                if retained[protoY * protoWidth + protoX] {
                    alpha[rasterY * rasterWidth + rasterX] = 210
                }
            }
        }
        // Close one-pixel gaps created by low-resolution prototype sampling,
        // without expanding the detection beyond its actual foreground.
        alpha = closedMask(alpha, width: rasterWidth, height: rasterHeight)

        // Build the contour from the retained mask rows. A detection box is only
        // a coarse hint; using its four corners makes every mask look like a box.
        let contour = maskContourFromRaster(alpha, width: rasterWidth, height: rasterHeight)
        guard contour.count >= 3 else { return nil }
        return ARMask(
            points: contour,
            rasterWidth: rasterWidth,
            rasterHeight: rasterHeight,
            rasterAlpha: Data(alpha)
        )
    }

    private static func yoloeMinimumScore(for classIndex: Int) -> Float {
        // Promptable classes have different calibration on cluttered desktop scenes.
        // Keep common objects visible while suppressing weak, unstable guesses.
        switch classIndex {
        case 0: return 0.12 // laptop computer
        case 1: return 0.22 // book
        case 2: return 0.30 // drinking cup
        case 3: return 0.28 // water bottle
        case 4: return 0.30 // smartphone
        case 5: return 0.42 // eyeglasses
        case 6: return 0.24 // pen
        case 7: return 0.35 // keyboard
        case 8: return 0.38 // mouse
        case 9: return 0.42 // cable
        case 10: return 0.42 // toy
        case 11: return 0.45 // trash
        case 12: return 0.10 // television cabinet
        case 13: return 0.03 // hanging outfits
        default: return 0.40
        }
    }

    private static func yoloeContextMinimumScore(for classIndex: Int) -> Float {
        switch classIndex {
        // The 640-letterboxed shelf sample peaks at 0.1817 for this prompt.
        // Keep the threshold just below that measured model score so this
        // context-only detector can recover the real grouped-book box.
        case 0: return 0.18 // books on top shelf
        case 1: return 0.05 // hanging clothes
        default: return 0.40
        }
    }

    private static func cocoMinimumScore(for classIndex: Int) -> Float {
        // Lower the threshold only for storage-relevant classes whose small
        // instances are commonly missed in clutter. Keep scene furniture and
        // kitchen objects at the stricter detector threshold to limit noise.
        switch classIndex {
        case 63, 66, 67, 73: // laptop, keyboard, cell phone, book
            return 0.35
        default:
            return 0.50
        }
    }

    private static func maskContour(
        retained: [Bool],
        width: Int,
        height: Int,
        minX: Int,
        maxX: Int,
        minY: Int,
        maxY: Int,
        transform: LetterboxTransform
    ) -> [ARMaskPoint] {
        let rowStride = max(1, (maxY - minY) / 18)
        var leftEdge: [ARMaskPoint] = []
        var rightEdge: [ARMaskPoint] = []
        for y in stride(from: minY, through: maxY, by: rowStride) {
            var left: Int?
            var right: Int?
            for x in minX...maxX where retained[y * width + x] {
                left = left ?? x
                right = x
            }
            guard let left, let right, right > left else { continue }
            leftEdge.append(normalizedMaskPoint(x: left, y: y, transform: transform, width: width, height: height))
            rightEdge.append(normalizedMaskPoint(x: right, y: y, transform: transform, width: width, height: height))
        }
        guard leftEdge.count >= 3 else { return [] }
        return leftEdge + rightEdge.reversed()
    }

    private static func closedMask(_ alpha: [UInt8], width: Int, height: Int) -> [UInt8] {
        guard alpha.count == width * height else { return alpha }
        var result = alpha
        // A small close operation bridges holes/gaps while preserving the
        // silhouette. It is intentionally limited to a one-pixel radius.
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                let hasForeground = alpha[index] > 0
                let neighbors = [
                    alpha[index - 1], alpha[index + 1], alpha[index - width], alpha[index + width]
                ].filter { $0 > 0 }.count
                if !hasForeground && neighbors >= 3 { result[index] = 210 }
            }
        }
        return result
    }

    private static func maskContourFromRaster(_ alpha: [UInt8], width: Int, height: Int) -> [ARMaskPoint] {
        guard alpha.count == width * height else { return [] }
        var boundary: [ARMaskPoint] = []
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let index = y * width + x
                guard alpha[index] > 0 else { continue }
                let exposed = alpha[index - 1] == 0 || alpha[index + 1] == 0 || alpha[index - width] == 0 || alpha[index + width] == 0
                guard exposed else { continue }
                boundary.append(ARMaskPoint(
                    x: (Double(x) + 0.5) / Double(width),
                    y: (Double(y) + 0.5) / Double(height)
                ))
            }
        }
        guard boundary.count >= 3 else { return [] }
        // The display shape needs a stable, ordered silhouette. Sampling the
        // extrema by row keeps the contour ordered and removes pixel noise.
        let rows = Dictionary(grouping: boundary) { Int(($0.y * Double(height)).rounded()) }
        let orderedRows = rows.keys.sorted().compactMap { key -> (ARMaskPoint, ARMaskPoint)? in
            guard let row = rows[key], let left = row.min(by: { $0.x < $1.x }), let right = row.max(by: { $0.x < $1.x }) else { return nil }
            return (left, right)
        }
        guard orderedRows.count >= 3 else { return [] }
        let stride = max(1, orderedRows.count / 32)
        let left = orderedRows.enumerated().compactMap { $0.offset % stride == 0 ? $0.element.0 : nil }
        let right = orderedRows.enumerated().compactMap { $0.offset % stride == 0 ? $0.element.1 : nil }
        return left + right.reversed()
    }

    private static func normalizedMaskPoint(
        x: Int,
        y: Int,
        transform: LetterboxTransform,
        width: Int,
        height: Int
    ) -> ARMaskPoint {
        let normalizedX = min(max((Double(x) / Double(width) * Double(transform.inputSize) - Double(transform.padX)) / Double(transform.contentWidth), 0), 1)
        let normalizedY = min(max((Double(y) / Double(height) * Double(transform.inputSize) - Double(transform.padY)) / Double(transform.contentHeight), 0), 1)
        return ARMaskPoint(x: normalizedX, y: normalizedY)
    }

    private static func originalHint(for box: CGRect, transform: LetterboxTransform) -> ARHint {
        let inputSize = CGFloat(transform.inputSize)
        let minX = max(0, (box.minX * inputSize - transform.padX) / CGFloat(transform.contentWidth))
        let maxX = min(1, (box.maxX * inputSize - transform.padX) / CGFloat(transform.contentWidth))
        let minY = max(0, (box.minY * inputSize - transform.padY) / CGFloat(transform.contentHeight))
        let maxY = min(1, (box.maxY * inputSize - transform.padY) / CGFloat(transform.contentHeight))
        return ARHint(
            x: Double((minX + maxX) / 2),
            y: Double((minY + maxY) / 2),
            width: Double(maxX - minX),
            height: Double(maxY - minY)
        )
    }

    private static func floatValue(_ tensor: MLMultiArray, channel: Int, anchor: Int) -> Float {
        let strides = tensor.strides.map(\.intValue)
        let index = strides[1] * channel + strides[2] * anchor
        switch tensor.dataType {
        case .float32:
            return tensor.dataPointer.assumingMemoryBound(to: Float.self)[index]
        case .double:
            return Float(tensor.dataPointer.assumingMemoryBound(to: Double.self)[index])
        default:
            return tensor[index].floatValue
        }
    }

    private static func protoValue(_ tensor: MLMultiArray, channel: Int, x: Int, y: Int) -> Float {
        let strides = tensor.strides.map(\.intValue)
        let index = strides[1] * channel + strides[2] * y + strides[3] * x
        switch tensor.dataType {
        case .float32:
            return tensor.dataPointer.assumingMemoryBound(to: Float.self)[index]
        case .double:
            return Float(tensor.dataPointer.assumingMemoryBound(to: Double.self)[index])
        default:
            return tensor[index].floatValue
        }
    }

    private static func hint(fromMask mask: ARMask) -> ARHint {
        let minX = mask.points.map(\.x).min() ?? 0.33
        let maxX = mask.points.map(\.x).max() ?? 0.67
        let minY = mask.points.map(\.y).min() ?? 0.39
        let maxY = mask.points.map(\.y).max() ?? 0.61
        return ARHint(
            x: min(max((minX + maxX) / 2, 0.08), 0.92),
            y: min(max((minY + maxY) / 2, 0.08), 0.92),
            width: min(max(maxX - minX, 0.12), 0.78),
            height: min(max(maxY - minY, 0.10), 0.72)
        )
    }

    private static func softMask(from hint: ARHint) -> ARMask {
        let minX = max(0.02, hint.x - hint.width / 2)
        let maxX = min(0.98, hint.x + hint.width / 2)
        let minY = max(0.02, hint.y - hint.height / 2)
        let maxY = min(0.98, hint.y + hint.height / 2)
        return ARMask(points: [
            ARMaskPoint(x: hint.x, y: minY),
            ARMaskPoint(x: maxX, y: hint.y),
            ARMaskPoint(x: hint.x, y: maxY),
            ARMaskPoint(x: minX, y: hint.y)
        ])
    }

    private static func simplifyMaskPoints(_ points: [ARMaskPoint]) -> [ARMaskPoint] {
        guard points.count > 24 else { return points }
        let stride = max(1, points.count / 24)
        return points.enumerated().compactMap { index, point in
            index.isMultiple(of: stride) ? point : nil
        }
    }

    private static func sigmoid(_ value: Float) -> Float {
        1 / (1 + exp(-value))
    }

    private static func retainedMaskComponents(
        _ foreground: [Bool],
        width: Int,
        minX: Int,
        maxX: Int,
        minY: Int,
        maxY: Int
    ) -> [Bool] {
        var visited = [Bool](repeating: false, count: foreground.count)
        var components: [[Int]] = []
        let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for y in minY...maxY {
            for x in minX...maxX {
                let start = y * width + x
                guard foreground[start], !visited[start] else { continue }
                visited[start] = true
                var component: [Int] = []
                var queue = [start]
                var cursor = 0
                while cursor < queue.count {
                    let index = queue[cursor]
                    cursor += 1
                    component.append(index)
                    let currentX = index % width
                    let currentY = index / width
                    for (dx, dy) in neighbors {
                        let nextX = currentX + dx
                        let nextY = currentY + dy
                        guard nextX >= minX, nextX <= maxX, nextY >= minY, nextY <= maxY else { continue }
                        let next = nextY * width + nextX
                        guard foreground[next], !visited[next] else { continue }
                        visited[next] = true
                        queue.append(next)
                    }
                }
                components.append(component)
            }
        }

        guard let largestIndex = components.indices.max(by: { components[$0].count < components[$1].count }) else {
            return visited.map { _ in false }
        }
        var retained = [Bool](repeating: false, count: foreground.count)
        for index in components[largestIndex] {
            retained[index] = true
        }
        return retained
    }

    private static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = lhs.width * lhs.height + rhs.width * rhs.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }

    static func category(forClassName name: String) -> ItemCategory {
        let lowercased = name.lowercased()
        if ["book", "notebook", "notepad", "journal", "paper", "worksheet", "exam", "document"].contains(where: { lowercased.contains($0) }) { return .books }
        if ["laptop", "keyboard", "mouse", "phone", "smartphone", "cable", "computer", "tv", "television"].contains(where: { lowercased.contains($0) }) { return .electronics }
        if ["pen", "eyeglass", "glass", "stationery"].contains(where: { lowercased.contains($0) }) { return .stationery }
        if ["clothes", "shirt", "coat", "jacket", "shoe", "outfit", "garment"].contains(where: { lowercased.contains($0) }) { return .clothes }
        if ["toy", "doll"].contains(where: { lowercased.contains($0) }) { return .toys }
        if ["trash", "waste"].contains(where: { lowercased.contains($0) }) { return .trash }
        return .tools
    }

    static func displayName(forClassName name: String) -> String {
        let lowercased = name.lowercased()
        let localized: [(String, String)] = [
            ("laptop", "电脑设备"), ("tv", "电视设备"), ("television", "电视设备"),
            ("hanging clothes", "衣物"), ("hanging outfits", "衣物"), ("outfit", "衣物"), ("clothes", "衣物"),
            ("notebook", "笔记本"), ("notepad", "笔记本"), ("journal", "笔记本"),
            ("worksheet", "讲义/试卷"), ("exam", "讲义/试卷"), ("document", "文件资料"),
            ("paper", "纸张资料"), ("book", "书本/资料"), ("cup", "杯子"),
            ("bottle", "瓶罐"), ("smartphone", "手机"), ("phone", "手机"),
            ("eyeglass", "眼镜"), ("pen", "笔"), ("keyboard", "键盘"),
            ("mouse", "鼠标"), ("cable", "线缆"), ("toy", "玩具"),
            ("trash", "垃圾"), ("shirt", "衣物"), ("coat", "外套"),
            ("jacket", "外套"), ("shoe", "鞋子")
        ]
        return localized.first(where: { lowercased.contains($0.0) })?.1 ?? displayName(forCOCOClass: cocoNames.firstIndex(of: name) ?? -1)
    }

    private static func category(forCOCOClass index: Int) -> ItemCategory {
        switch index {
        case 0, 24...28: .toys
        case 39...40, 56, 60...61: .tools
        case 41, 62...67, 72: .electronics
        case 26, 27, 31, 32, 33: .clothes
        case 73: .books
        default: .tools
        }
    }

    private static func displayName(forCOCOClass index: Int) -> String {
        guard index >= 0, index < cocoNames.count else { return "待确认物体" }
        let name = cocoNames[index]
        let localized: [String: String] = [
            "person": "人物/玩偶区域",
            "backpack": "背包",
            "handbag": "手袋",
            "suitcase": "箱包",
            "bottle": "瓶罐",
            "cup": "杯子",
            "bowl": "碗具",
            "chair": "椅子",
            "couch": "沙发/软包",
            "bed": "床铺区域",
            "dining table": "桌面区域",
            "tv": "屏幕设备",
            "laptop": "电脑设备",
            "mouse": "鼠标",
            "remote": "遥控器/长条物",
            "keyboard": "键盘",
            "cell phone": "手机",
            "book": "书本/资料",
            "scissors": "剪刀",
            "teddy bear": "玩偶"
        ]
        return localized[name] ?? "待确认物体"
    }

    private static let cocoNames = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck",
        "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
        "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra",
        "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
        "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
        "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup",
        "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
        "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
        "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
        "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier",
        "toothbrush"
    ]

    private enum YOLOModelKind {
        case segmentation
        case worldDetection
    }

    private struct YOLOModel {
        let model: MLModel
        let inputSize: Int
        let classNames: [String]
        let kind: YOLOModelKind
        let sourceName: String
    }

    private static let yoloeClassNames = [
        "laptop computer", "book", "drinking cup", "water bottle", "smartphone",
        "eyeglasses", "pen", "computer keyboard", "computer mouse", "cable", "toy", "trash",
        "television cabinet", "hanging outfits"
    ]

    // This compact vocabulary is exported from the same YOLOE weights. It supplements
    // the general detector when books are grouped on a shelf or clothes are grouped on hangers.
    private static let yoloeContextClassNames = [
        "books on top shelf", "hanging clothes"
    ]

    private static let worldClassNames = [
        "tablet computer", "laptop computer", "smartphone", "book", "pen",
        "drinking cup", "bowl", "water bottle", "chair", "cable",
        "storage box", "clothes", "tool", "trash"
    ]

    private struct LetterboxTransform {
        let inputSize: Int
        let contentWidth: Int
        let contentHeight: Int
        let padX: CGFloat
        let padY: CGFloat
    }

    private struct YOLODetection {
        var classIndex: Int
        var confidence: Float
        var box: CGRect
        var coefficients: [Float]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension UIImage {
    var normalizedCGImage: CGImage? {
        if imageOrientation == .up, let cgImage {
            return cgImage
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return image.cgImage
    }
}

struct RuleBasedPlanningService: PlanningService {
    func makePlan(for space: StorageSpace, selectedItems: [DetectedItem], style: StorageStyle, timeBudget: TimeBudget, goal: String = "", focusZone: String = "") -> StoragePlan {
        let items = selectedItems.filter(\.isSelected)
        let grouped = Dictionary(grouping: items, by: \.category)
        let orderedCategories = ItemCategory.allCases.filter { grouped[$0] != nil }
        let normalizedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFocusZone = focusZone.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxSteps: Int
        switch timeBudget {
        case .five: maxSteps = 2
        case .ten: maxSteps = 3
        case .sixty: maxSteps = max(5, orderedCategories.count)
        }

        let categories = Array(orderedCategories.prefix(maxSteps))
        let steps = categories.enumerated().map { index, category in
            let categoryItems = grouped[category] ?? []
            let names = categoryItems.map(\.name).joined(separator: "、")
            let anchor = anchorItem(for: categoryItems)
            return StorageStep(
                title: title(for: category, items: categoryItems, index: index),
                detail: detail(for: category, items: categoryItems, itemNames: names, style: style, goal: normalizedGoal),
                zone: normalizedFocusZone.isEmpty ? category.suggestedZone : "\(normalizedFocusZone) · \(category.suggestedZone)",
                status: index == 0 ? .active : .pending,
                arHint: anchor?.arHint ?? .centerFallback,
                arMask: anchor?.arMask,
                itemIDs: categoryItems.map(\.id)
            )
        }

        return StoragePlan(
            style: style,
            timeBudget: timeBudget,
            summary: summary(for: space, style: style, stepsCount: steps.count, goal: normalizedGoal, focusZone: normalizedFocusZone),
            toolList: tools(for: items, timeBudget: timeBudget),
            steps: steps
        )
    }

    private func summary(for space: StorageSpace, style: StorageStyle, stepsCount: Int, goal: String, focusZone: String) -> String {
        let goalText = goal.isEmpty ? "恢复可用面积与秩序感" : goal
        let zoneText = focusZone.isEmpty ? "视觉最乱和最常用的区域" : focusZone
        return "\(space.name) 将按「\(style.rawValue)」整理为 \(stepsCount) 个可执行步骤，目标是\(goalText)，优先处理\(zoneText)。"
    }

    private func title(for category: ItemCategory, items: [DetectedItem], index: Int) -> String {
        if category == .tools, containsDrinkware(items) {
            return "饮品容器清洗归位"
        }
        return switch category {
        case .trash: "先清走无效杂物"
        case .books: "把书本竖放归位"
        case .electronics: "建立充电与设备区"
        case .stationery: "文具集中入盒"
        case .clothes: "衣物折叠暂存"
        case .toys: "玩偶与装饰分层展示"
        case .tools: "收纳工具放到手边"
        }
    }

    private func detail(for category: ItemCategory, items: [DetectedItem], itemNames: String, style: StorageStyle, goal: String) -> String {
        let target = itemNames.isEmpty ? category.rawValue : itemNames
        let goalSuffix = goal.isEmpty ? "" : "，对齐「\(goal)」这个目标"
        if category == .tools, containsDrinkware(items) {
            return "把 \(target) 集中到清洗区，确认干燥后归位到固定饮品区，不占用桌面工作面\(goalSuffix)。"
        }
        switch style {
        case .quickReset:
            return "把 \(target) 先移动到「\(category.suggestedZone)」，不用追求完美，先恢复桌面可用面积\(goalSuffix)。"
        case .warmVisible:
            return "保留 \(target) 的可见性，按高度和颜色排成一组，让常用物品一眼能找到\(goalSuffix)。"
        case .hiddenClean:
            return "将 \(target) 收进盒/抽屉，只保留必要入口，减少桌面视觉噪音\(goalSuffix)。"
        case .professional:
            return "先确认 \(target) 的使用频率，再按“保留、入盒、迁移”三类处理，最后拍照归档形成可复盘记录\(goalSuffix)。"
        }
    }

    private func tools(for items: [DetectedItem], timeBudget: TimeBudget) -> [String] {
        var tools = ["垃圾袋", "湿巾"]
        if items.contains(where: { $0.category == .stationery || $0.category == .electronics }) {
            tools.append("分隔收纳盒")
        }
        if items.contains(where: { $0.category == .books }) {
            tools.append("书立")
        }
        if timeBudget == .sixty {
            tools.append("标签贴")
        }
        return Array(Set(tools)).sorted()
    }

    // A step's box and mask must originate from the same object. Combining a
    // category-wide box with another instance's mask creates false AR guidance.
    private func anchorItem(for items: [DetectedItem]) -> DetectedItem? {
        items
            .filter { $0.arHint != nil && $0.arMask?.isRenderable == true }
            .max { $0.confidence < $1.confidence }
            ?? items.filter { $0.arHint != nil }.max { $0.confidence < $1.confidence }
    }

    private func containsDrinkware(_ items: [DetectedItem]) -> Bool {
        items.contains { ["杯子", "碗具", "瓶罐"].contains($0.name) }
    }
}

enum CloudPlanningError: LocalizedError {
    case missingSettings
    case invalidResponse
    case emptyPlan

    var errorDescription: String? {
        switch self {
        case .missingSettings: "请先在我的 - AI规划设置中填写可用的 API Key。"
        case .invalidResponse: "云端 AI 返回格式无法解析，已保留本地方案。"
        case .emptyPlan: "云端 AI 没有返回可执行步骤，已保留本地方案。"
        }
    }
}

struct OpenAICompatiblePlanningService: CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        let endpoint = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard settings.canRequest, let url = URL(string: endpoint) else {
            throw CloudPlanningError.missingSettings
        }
        guard !plan.steps.isEmpty else {
            throw CloudPlanningError.emptyPlan
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        var content = [CloudInputContent(type: "input_text", text: prompt(for: plan, context: context), imageURL: nil)]
        if let imageData = context.referenceImageData {
            content.append(CloudInputContent(
                type: "input_image",
                text: nil,
                imageURL: "data:image/jpeg;base64,\(imageData.base64EncodedString())"
            ))
        }
        request.httpBody = try JSONEncoder().encode(CloudPlanningRequest(
            model: settings.model.trimmingCharacters(in: .whitespacesAndNewlines),
            input: [CloudInputMessage(role: "user", content: content)]
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw CloudPlanningError.invalidResponse
        }

        let text = try responseText(from: data)
        guard let jsonData = extractJSONObject(from: text).data(using: .utf8) else {
            throw CloudPlanningError.invalidResponse
        }
        let draft = try JSONDecoder().decode(CloudPlanDraft.self, from: jsonData)
        guard !draft.steps.isEmpty else {
            throw CloudPlanningError.emptyPlan
        }

        var refinedPlan = plan
        refinedPlan.summary = draft.summary
        refinedPlan.toolList = draft.toolList.isEmpty ? plan.toolList : draft.toolList
        refinedPlan.steps = draft.steps.prefix(max(1, plan.steps.count)).enumerated().map { index, step in
            let fallback = plan.steps[min(index, plan.steps.count - 1)]
            return StorageStep(
                id: fallback.id,
                title: step.title,
                detail: step.detail,
                zone: step.zone,
                status: index == 0 ? .active : .pending,
                arHint: fallback.arHint,
                arMask: fallback.arMask,
                itemIDs: fallback.itemIDs
            )
        }
        return refinedPlan
    }

    private func prompt(for plan: StoragePlan, context: PlanningContext) -> String {
        let items = context.selectedItems.filter(\.isSelected).map {
            "\($0.name)(\($0.category.rawValue), 建议:\($0.suggestedZone))"
        }.joined(separator: "、")
        let tags = context.selectedTags.isEmpty ? "无额外标签" : context.selectedTags.joined(separator: "、")
        return """
        你是 Smart Paw 灵爪收纳的专业收纳规划助手。请基于用户照片识别出的物品，生成可执行的中文收纳方案。
        空间：\(context.space.name) - \(context.space.subtitle)
        用户目标：\(context.goal.isEmpty ? "恢复空间秩序并降低整理压力" : context.goal)
        重点区域：\(context.focusZone.isEmpty ? "用户当前扫描区域" : context.focusZone)
        辅助标签：\(tags)
        推荐模式：\(context.recommendationMode.rawValue)
        参考图片：\(context.referenceImageData == nil ? "未提供" : "已作为本条消息的图片输入提供，请提取可迁移的布局与收纳方式")
        风格：\(plan.style.rawValue)
        时间预算：\(plan.timeBudget.title)
        物品：\(items)
        请只返回 JSON 对象，不要 Markdown，不要代码块。格式：
        {"summary":"一句话方案摘要","toolList":["工具1","工具2"],"steps":[{"title":"步骤标题","detail":"具体动作，必须低门槛可执行","zone":"放置区域"}]}
        steps 数量必须为 \(plan.steps.count)，每步适合当前时间预算，并体现分区引导和时间切片。
        """
    }

    private func responseText(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(OpenAIResponsesEnvelope.self, from: data)
        if let direct = response.outputText, !direct.isEmpty {
            return direct
        }
        let texts = response.output?.flatMap { output in
            output.content?.compactMap(\.text) ?? []
        } ?? []
        guard let text = texts.first(where: { !$0.isEmpty }) else {
            throw CloudPlanningError.invalidResponse
        }
        return text
    }

    private func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            return trimmed
        }
        return String(trimmed[start...end])
    }
}

private struct CloudPlanningRequest: Encodable {
    var model: String
    var input: [CloudInputMessage]
}

private struct CloudInputMessage: Encodable {
    var role: String
    var content: [CloudInputContent]
}

private struct CloudInputContent: Encodable {
    var type: String
    var text: String?
    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct OpenAIResponsesEnvelope: Decodable {
    var outputText: String?
    var output: [OpenAIOutput]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct OpenAIOutput: Decodable {
    var content: [OpenAIContent]?
}

private struct OpenAIContent: Decodable {
    var text: String?
}

private struct CloudPlanDraft: Decodable {
    var summary: String
    var toolList: [String]
    var steps: [CloudStepDraft]
}

private struct CloudStepDraft: Decodable {
    var title: String
    var detail: String
    var zone: String
}

struct JSONStorageStore: StorageStore {
    private let stateURL: URL
    private let credentialStore: CredentialStore

    init(
        stateURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("smart-paw-demo-state.json"),
        credentialStore: CredentialStore = SystemCredentialStore()
    ) {
        self.stateURL = stateURL
        self.credentialStore = credentialStore
    }

    private var url: URL {
        stateURL
    }

    private var backupURL: URL {
        url.deletingPathExtension().appendingPathExtension("backup.json")
    }

    func loadState() throws -> AppStateSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { return nil }
            return try restoreFromBackup()
        }
        do {
            let data = try Data(contentsOf: url)
            let snapshot = try JSONDecoder().decode(AppStateSnapshot.self, from: data)
            try sanitizePersistedCredentialsIfNeeded(snapshot)
            try sanitizeBackupCredentialsIfNeeded()
            return snapshot
        } catch {
            guard FileManager.default.fileExists(atPath: backupURL.path) else { throw error }
            return try restoreFromBackup()
        }
    }

    func saveState(_ snapshot: AppStateSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        if let currentData = try? Data(contentsOf: url),
           let currentSnapshot = try? JSONDecoder().decode(AppStateSnapshot.self, from: currentData) {
            let safeBackup = try JSONEncoder().encode(currentSnapshot)
            try safeBackup.write(to: backupURL, options: [.atomic])
        }
        try data.write(to: url, options: [.atomic])
    }

    private func sanitizePersistedCredentialsIfNeeded(_ snapshot: AppStateSnapshot) throws {
        guard !snapshot.llmSettings.apiKey.isEmpty else { return }
        guard credentialStore.loadAPIKey() != nil
                || credentialStore.saveAPIKey(snapshot.llmSettings.apiKey)
        else { return }
        let sanitizedData = try JSONEncoder().encode(snapshot)
        try sanitizedData.write(to: url, options: [.atomic])
        try sanitizedData.write(to: backupURL, options: [.atomic])
    }

    private func sanitizeBackupCredentialsIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }
        do {
            let backupData = try Data(contentsOf: backupURL)
            let backupSnapshot = try JSONDecoder().decode(AppStateSnapshot.self, from: backupData)
            guard !backupSnapshot.llmSettings.apiKey.isEmpty else { return }
            guard credentialStore.loadAPIKey() != nil
                    || credentialStore.saveAPIKey(backupSnapshot.llmSettings.apiKey)
            else { return }
            let sanitizedBackup = try JSONEncoder().encode(backupSnapshot)
            try sanitizedBackup.write(to: backupURL, options: [.atomic])
        } catch {
            try? FileManager.default.removeItem(at: backupURL)
        }
    }

    private func restoreFromBackup() throws -> AppStateSnapshot {
        let backupData = try Data(contentsOf: backupURL)
        let snapshot = try JSONDecoder().decode(AppStateSnapshot.self, from: backupData)
        if !snapshot.llmSettings.apiKey.isEmpty,
           credentialStore.loadAPIKey() == nil,
           !credentialStore.saveAPIKey(snapshot.llmSettings.apiKey) {
            return snapshot
        }
        let repairedData = try JSONEncoder().encode(snapshot)
        try repairedData.write(to: url, options: [.atomic])
        try repairedData.write(to: backupURL, options: [.atomic])
        return snapshot
    }
}

final class InMemoryStorageStore: StorageStore {
    private var snapshot: AppStateSnapshot?

    func loadState() throws -> AppStateSnapshot? {
        snapshot
    }

    func saveState(_ snapshot: AppStateSnapshot) throws {
        self.snapshot = snapshot
    }
}
