import Foundation
import UIKit

/// 识别总入口：本地 CoreML 管线 + 云端多模态大模型。
///
/// 本地模型给出精确的分割轮廓（AR 叠加要用到），但它在真机上会因为
/// 模型编译失败、阈值过严或场景不匹配而返回空结果——这正是"拍完认不出东西"
/// 的直接原因。云端多模态模型负责给出可靠的中文物品名与类别。
/// 两者的结果在这里合并：名称与类别以云端为准，轮廓沿用本地的精确 mask。
final class RecognitionRouter: ScanService, @unchecked Sendable {
    static let shared = RecognitionRouter()

    /// 由 AppViewModel 注入，用来读取用户当前保存的 AI 设置。
    var settingsProvider: (() -> LLMSettings)?

    private let local = YOLOSegmentationScanService()
    private let cloud = CloudVisionRecognitionService()
    private let lock = NSLock()
    private var report: [String: String] = [:]
    private var cachedCloudLive: [DetectedItem] = []
    private var cachedCloudLiveAt = Date.distantPast
    private var cloudLiveInFlight = false

    private init() {}

    var diagnostics: [String: String] {
        lock.lock(); defer { lock.unlock() }
        return report
    }

    // MARK: - 拍照识别

    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        try await scanImage(image, allowsCloud: true)
    }

    /// 连拍时云端只跑一次：多模态模型看一张就能概括整个空间，
    /// 其余照片交给本地模型补充，避免每张都等一次网络往返。
    func scanImage(_ image: UIImage, allowsCloud: Bool) async throws -> [DetectedItem] {
        let settings = settingsProvider?() ?? .default
        let useCloud = allowsCloud && settings.canRequestVision
        async let localItems = localItems(for: image)
        async let cloudItems = useCloud ? cloudItems(for: image, settings: settings) : [DetectedItem]()
        let (local, cloud) = await (localItems, cloudItems)
        return Self.combine(local: local, cloud: cloud, live: false) { [weak self] summary in
            self?.record(summary, cloudEnabled: useCloud)
        }
    }

    // MARK: - AR 实时扫描

    /// 本地逐帧跑保证实时性；云端每 4 秒补一次，用它的名称覆盖本地的不确定标签。
    func scanLiveImage(_ image: UIImage) async -> [DetectedItem] {
        let settings = settingsProvider?() ?? .default
        let useCloud = settings.canRequestVision
        if useCloud { scheduleCloudLive(image, settings) }
        async let localItems = local.scanLiveImage(image)
        let local = await localItems
        lock.lock()
        let fresh = Date().timeIntervalSince(cachedCloudLiveAt) < 8 ? cachedCloudLive : []
        lock.unlock()
        return Self.combine(local: local, cloud: fresh, live: true) { [weak self] summary in
            self?.record(summary, cloudEnabled: useCloud)
        }
    }

    private func scheduleCloudLive(_ image: UIImage, _ settings: LLMSettings) {
        lock.lock()
        let now = Date()
        guard now.timeIntervalSince(cachedCloudLiveAt) > 4, !cloudLiveInFlight else {
            lock.unlock()
            return
        }
        cloudLiveInFlight = true
        lock.unlock()
        let cloud = self.cloud
        Task.detached(priority: .utility) { [weak self] in
            let items = (try? await cloud.recognize(image: image, settings: settings)) ?? []
            guard let self else { return }
            self.lock.lock()
            self.cloudLiveInFlight = false
            if !items.isEmpty {
                self.cachedCloudLive = items
                self.cachedCloudLiveAt = Date()
            }
            let cloudCount = items.count
            self.lock.unlock()
            print("SMARTPAW_SCAN live-cloud=\(cloudCount)")
        }
    }

    // MARK: - 结果合并

    private static func combine(
        local: [DetectedItem],
        cloud: [DetectedItem],
        live: Bool,
        record: ([String: String]) -> Void
    ) -> [DetectedItem] {
        let limit = live ? 8 : 12
        if cloud.isEmpty {
            record([
                "source": local.isEmpty ? "空" : "本地",
                "本地": "\(local.count)",
                "云端": "0",
            ])
            return Array(local.prefix(limit))
        }
        record([
            "source": local.isEmpty ? "云端" : "本地+云端",
            "本地": "\(local.count)",
            "云端": "\(cloud.count)",
        ])
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
            } else {
                item.arHint = ARHint.centerFallback
                item.arMask = softMask(for: ARHint.centerFallback)
            }
            merged.append(item)
        }
        // 本地单独认出的高置信物体（云端漏掉的）继续保留，避免漏检。
        let extras = local.enumerated()
            .filter { !usedLocal.contains($0.offset) && $0.element.confidence >= 0.45 }
            .map(\.element)
        merged.append(contentsOf: extras)
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
                score += Self.intersectionOverUnion(hint, candidateHint)
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
            return try await local.scanImage(image)
        } catch {
            print("SMARTPAW_SCAN local-error \(error.localizedDescription)")
            return []
        }
    }

    private func cloudItems(for image: UIImage, settings: LLMSettings) async -> [DetectedItem] {
        do {
            let items = try await cloud.recognize(image: image, settings: settings)
            print("SMARTPAW_SCAN cloud=\(items.count) names=\(items.map(\.name).joined(separator: "、"))")
            return items
        } catch {
            print("SMARTPAW_SCAN cloud-error \(error.localizedDescription)")
            lock.lock()
            report["云端错误"] = error.localizedDescription
            lock.unlock()
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
