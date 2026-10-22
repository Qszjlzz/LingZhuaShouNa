import Foundation
import UIKit

/// 照片使用已授权的大模型识别；失败或未配置时才运行设备端模型。
/// AR 实时预览仍使用本地模型。大模型给出的框是粗定位，不冒充真实分割。
final class RecognitionRouter: ScanService, @unchecked Sendable {
    static let shared = RecognitionRouter()

    /// 由 AppViewModel 注入，用来读取用户当前保存的 AI 设置。
    var settingsProvider: (() -> LLMSettings)?

    private let local = YOLOSegmentationScanService()
    private let stillLocalScan: (UIImage) async throws -> [DetectedItem]
    private let cloudScan: (UIImage, LLMSettings) async throws -> [DetectedItem]
    /// 开放词表语义层：本地 YOLO 词表里没有耳机 / 鼠标垫 / 发夹这类小物件，
    /// 由它对已检出的候选框重新命名（仍是设备端模型，不联网）。
    private let semantic = SemanticRecognitionScanService()
    private let lock = NSLock()
    private var report: [String: String] = [:]

    init(
        localScan: @escaping (UIImage) async throws -> [DetectedItem] = { try await YOLOSegmentationScanService().scanImage($0) },
        cloudScan: @escaping (UIImage, LLMSettings) async throws -> [DetectedItem] = { try await CloudVisionRecognitionService().recognize(image: $0, settings: $1) }
    ) {
        self.stillLocalScan = localScan
        self.cloudScan = cloudScan
    }

    var diagnostics: [String: String] {
        lock.lock(); defer { lock.unlock() }
        return report
    }

    // MARK: - 拍照识别

    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        try await scanImage(image, allowsCloud: true)
    }

    /// 每张照片有独立视角，不能用首张的识别结果代替之后的照片。
    func scanImage(_ image: UIImage, allowsCloud: Bool) async throws -> [DetectedItem] {
        let settings = settingsProvider?() ?? .default
        let useCloud = allowsCloud && settings.canRequestVision
        if useCloud {
            do {
                let items = try await cloudScan(image, settings)
                try Task.checkCancellation()
                record([
                    "source": "大模型", "本地": "未运行", "云端": "\(items.count)",
                    "返回": "\(items.count)", "云端状态": "成功", "定位": "大模型粗框（非分割）"
                ], cloudEnabled: true)
                // A valid empty scene stays empty. Local predictions must not add
                // objects rejected or absent from a successful cloud response.
                return items
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                let items = await localItems(for: image)
                try Task.checkCancellation()
                record([
                    "source": "本地降级", "本地": "\(items.count)", "云端": "0",
                    "返回": "\(items.count)", "云端状态": "失败",
                    "云端错误": error.localizedDescription
                ], cloudEnabled: true)
                return items
            }
        }
        try Task.checkCancellation()
        let items = await localItems(for: image)
        try Task.checkCancellation()
        record([
            "source": "本地", "本地": "\(items.count)", "云端": "未启用",
            "返回": "\(items.count)", "云端状态": "未配置、未授权或显式本地"
        ], cloudEnabled: false)
        return items
    }

    // MARK: - AR 实时扫描
    //
    // AR 是逐帧实时叠加，只能用设备上的本地模型：一来云端往返（数秒）跟不上
    // 实时画面，二来 AR 的气泡必须贴着真实轮廓走，云端只给名字不给轮廓。
    // 所以这里与拍照识别完全分开，不请求任何网络、不读 AI 设置。

    func scanLiveImage(_ image: UIImage) async -> [DetectedItem] {
        var items = await local.scanLiveImage(image)
        // 本地词表认得太少时补一次开放词表命名：把"认成别的东西"的候选框改成真实名称，
        // 只对少量候选跑，控制在几十毫秒级，不会拖慢常规帧。
        if items.count < 3 {
            items = await semantic.refineLiveItems(items, in: image)
        }
        lock.lock(); defer { lock.unlock() }
        let summary = [
            "source": items.isEmpty ? "空" : "本地实时+语义",
            "本地": "\(items.count)",
            "云端": "未启用",
        ]
        report = summary
        report["云端已配置"] = "不适用（AR 走本地实时）"
        report["本地模型"] = "\(YOLOSegmentationScanService.loadedModelNames.joined(separator: "、"))"
        return Array(items.prefix(8))
    }

    // MARK: - 结果合并

    static func combine(
        local: [DetectedItem],
        cloud: [DetectedItem],
        live: Bool,
        record: ([String: String]) -> Void
    ) -> [DetectedItem] {
        // A still photo can contain more than twelve possessions. Keep the full
        // detector result for planning; only live AR needs a display budget.
        let limit = live ? 8 : Int.max
        if cloud.isEmpty {
            record([
                "source": local.isEmpty ? "空" : "本地",
                "本地": "\(local.count)",
                "云端": "0",
                "返回": "\(min(local.count, limit))",
                "截断": "\(max(0, local.count - limit))",
            ])
            return Array(local.prefix(limit))
        }
        var merged: [DetectedItem] = []
        var usedLocal = Set<Int>()
        for var item in cloud {
            if let index = bestLocalIndex(for: item, in: local, excluding: usedLocal) {
                usedLocal.insert(index)
                // 云端负责"这是什么"，本地负责"它在哪、轮廓是什么"。
                item.arHint = local[index].arHint ?? item.arHint
                item.arMask = local[index].arMask ?? softMask(for: item.arHint)
                item.confidence = max(item.confidence, local[index].confidence)
            } else if let hint = item.arHint {
                item.arMask = softMask(for: hint)
            }
            merged.append(item)
        }
        // 本地单独认出的高置信物体（云端漏掉的）继续保留，避免漏检。
        let extras = local.enumerated()
            .filter { !usedLocal.contains($0.offset) && $0.element.confidence >= 0.45 }
            .map(\.element)
        merged.append(contentsOf: extras)
        record([
            "source": local.isEmpty ? "云端" : "本地+云端",
            "本地": "\(local.count)",
            "云端": "\(cloud.count)",
            "返回": "\(min(merged.count, limit))",
            "截断": "\(max(0, merged.count - limit))",
        ])
        return Array(merged.prefix(limit))
    }

    /// 把云端的一条物品对应到本地的某一块分割区域上。
    /// 位置重叠、类别相同、名称相近都会加分，只有综合可信时才沿用本地轮廓。
    private static func bestLocalIndex(
        for item: DetectedItem,
        in local: [DetectedItem],
        excluding used: Set<Int>
    ) -> Int? {
        var bestIndex: Int?
        var bestScore = 0.0
        for (index, candidate) in local.enumerated() where !used.contains(index) {
            var score = 0.0
            if let hint = item.arHint, let candidateHint = candidate.arHint {
                let overlap = Self.intersectionOverUnion(hint, candidateHint)
                // Two cups at opposite ends of a desk are separate objects.
                // Shared category/name must not move one label to the other's mask.
                guard overlap >= 0.1 else { continue }
                score += overlap
            }
            if candidate.category == item.category { score += 0.25 }
            if candidate.name == item.name {
                score += 0.35
            } else if !Set(candidate.name).intersection(Set(item.name)).isEmpty {
                // 名称有公共字（例如"马克杯"与"杯子"）也算同一个东西。
                score += 0.12
            }
            guard score >= 0.32, score > bestScore else { continue }
            bestScore = score
            bestIndex = index
        }
        return bestIndex
    }

    private static func intersectionOverUnion(_ lhs: ARHint, _ rhs: ARHint) -> Double {
        let lhsRect = CGRect(x: lhs.x - lhs.width / 2, y: lhs.y - lhs.height / 2, width: lhs.width, height: lhs.height)
        let rhsRect = CGRect(x: rhs.x - rhs.width / 2, y: rhs.y - rhs.height / 2, width: rhs.width, height: rhs.height)
        let intersection = lhsRect.intersection(rhsRect)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = lhsRect.width * lhsRect.height + rhsRect.width * rhsRect.height - intersectionArea
        return unionArea > 0 ? Double(intersectionArea / unionArea) : 0
    }

    /// 云端只给框，不给轮廓。这里生成一块矩形遮罩，让拍摄页与 AR 叠加仍能显示气泡。
    private static func softMask(for hint: ARHint?) -> ARMask? {
        guard let hint else { return nil }
        let minX = min(max(hint.x - hint.width / 2, 0), 1)
        let maxX = min(max(hint.x + hint.width / 2, 0), 1)
        let minY = min(max(hint.y - hint.height / 2, 0), 1)
        let maxY = min(max(hint.y + hint.height / 2, 0), 1)
        guard maxX > minX, maxY > minY else { return nil }
        let width = 48
        let height = 48
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width)
                let v = (Double(y) + 0.5) / Double(height)
                if u >= minX, u <= maxX, v >= minY, v <= maxY {
                    alpha[y * width + x] = 170
                }
            }
        }
        return ARMask(
            points: [
                ARMaskPoint(x: minX, y: minY),
                ARMaskPoint(x: maxX, y: minY),
                ARMaskPoint(x: maxX, y: maxY),
                ARMaskPoint(x: minX, y: maxY),
            ],
            rasterWidth: width,
            rasterHeight: height,
            rasterAlpha: Data(alpha)
        )
    }

    // MARK: - 底层调用

    private func localItems(for image: UIImage) async -> [DetectedItem] {
        do {
            return try await stillLocalScan(image)
        } catch {
            print("SMARTPAW_SCAN local-error \(error.localizedDescription)")
            return []
        }
    }

    private func record(_ summary: [String: String], cloudEnabled: Bool) {
        lock.lock(); defer { lock.unlock() }
        report = summary
        report["云端已配置"] = cloudEnabled ? "是" : "否"
        report["本地模型"] = "\(YOLOSegmentationScanService.loadedModelNames.joined(separator: "、"))"
        print("SMARTPAW_SCAN \(summary)")
    }
}
