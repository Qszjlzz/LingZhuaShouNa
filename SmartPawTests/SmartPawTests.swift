import XCTest
import UIKit
@testable import SmartPaw

final class SmartPawTests: XCTestCase {
    func testMobileCLIPResourcesLoadAndEncodeText() async throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "mobileclip_s0_image", withExtension: "mlmodelc"))
        XCTAssertNotNil(Bundle.main.url(forResource: "mobileclip_s0_text", withExtension: "mlmodelc"))
        XCTAssertNotNil(Bundle.main.url(forResource: "category_embeddings", withExtension: "json"))

        let imageEncoder = MobileCLIPFeatureExtractor.shared
        let textEncoder = MobileCLIPTextFeatureExtractor.shared
        XCTAssertTrue(imageEncoder.isAvailable, "MobileCLIP image encoder must load from the app bundle.")
        XCTAssertTrue(textEncoder.isAvailable, "MobileCLIP text encoder and tokenizer must load from the app bundle.")

        let embedding = try await textEncoder.extractTextFeature(from: "a photo of a book or notebook")
        XCTAssertEqual(embedding.count, 512)
        let length = sqrt(embedding.reduce(0) { $0 + ($1 * $1) })
        XCTAssertEqual(length, 1, accuracy: 0.001)
    }

    func testSemanticRecognitionRunsMobileCLIPOnBundledDeskPhoto() async throws {
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))
        let imageEmbedding = try await MobileCLIPFeatureExtractor.shared.extractImageFeature(from: image)
        XCTAssertEqual(imageEmbedding.count, 512)

        let service = SemanticRecognitionScanService()
        let items = try await service.scanImage(image)
        XCTAssertFalse(items.isEmpty, "Semantic recognition should preserve detector candidates.")
        XCTAssertTrue(service.backendStatus.semanticMatchingAvailable)
        let summary = items.map {
            "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%"
        }.joined(separator: "; ")
        print("SMARTPAW_MOBILECLIP_DESK \(summary)")
    }

    func testMobileCLIPEvaluationDatasetReportsSemanticBaseline() async throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/EvaluationScanTests/evaluation-dataset.json")
        let samples = try JSONDecoder().decode([EvaluationScanSample].self, from: Data(contentsOf: manifestURL))
        XCTAssertGreaterThanOrEqual(samples.count, 10)

        let service = SemanticRecognitionScanService()
        XCTAssertTrue(service.backendStatus.semanticMatchingAvailable)
        var hitCount = 0
        var totalItems = 0
        var totalConfidence = 0.0

        for sample in samples {
            let data = try Data(contentsOf: URL(fileURLWithPath: sample.file))
            let image = try XCTUnwrap(UIImage.downsampled(data: data))
            let items = try await service.scanImage(image)
            let categories = Set(items.map(\.category))
            let expected = Set(sample.expected.compactMap(EvaluationScanSample.category(for:)))
            let hit = !categories.isDisjoint(with: expected)
            if hit { hitCount += 1 }
            totalItems += items.count
            totalConfidence += items.map(\.confidence).reduce(0, +)
            let hitText = hit ? "yes" : "no"
            let names = items.map(\.name).joined(separator: ",")
            print("SMARTPAW_MOBILECLIP_EVAL \(sample.id)|hit:\(hitText)|items:\(items.count)|\(names)")
        }

        let hitRate = Double(hitCount) / Double(samples.count)
        let averageItems = Double(totalItems) / Double(samples.count)
        let averageConfidence = totalItems == 0 ? 0 : totalConfidence / Double(totalItems)
        let averageItemsText = String(format: "%.1f", averageItems)
        print("SMARTPAW_MOBILECLIP_SUMMARY samples:\(samples.count)|hit_rate:\(Int(hitRate * 100))%|avg_items:\(averageItemsText)|avg_conf:\(Int(averageConfidence * 100))%")
    }

    func testPlanningServiceCreatesDifferentStepCountsForTimeBudgets() {
        let service = RuleBasedPlanningService()
        let space = DemoData.spaces[0]

        let fiveMinutePlan = service.makePlan(for: space, selectedItems: DemoData.detectedItems, style: .quickReset, timeBudget: .five)
        let tenMinutePlan = service.makePlan(for: space, selectedItems: DemoData.detectedItems, style: .quickReset, timeBudget: .ten)

        XCTAssertEqual(fiveMinutePlan.steps.count, 2)
        XCTAssertEqual(tenMinutePlan.steps.count, 3)
        XCTAssertGreaterThan(tenMinutePlan.steps.count, fiveMinutePlan.steps.count)
    }

    func testPlanningServiceUsesUserGoalAndFocusZone() {
        let service = RuleBasedPlanningService()
        let plan = service.makePlan(
            for: DemoData.spaces[0],
            selectedItems: DemoData.detectedItems,
            style: .warmVisible,
            timeBudget: .ten,
            goal: "考研复习更顺手",
            focusZone: "书桌左侧"
        )

        XCTAssertTrue(plan.summary.contains("考研复习更顺手"))
        XCTAssertTrue(plan.summary.contains("书桌左侧"))
        XCTAssertTrue(plan.steps.allSatisfy { $0.zone.contains("书桌左侧") })
    }

    func testItemCategoryMapsToSuggestedStorageZone() {
        XCTAssertEqual(ItemCategory.books.suggestedZone, "书架 / 左侧竖放区")
        XCTAssertEqual(ItemCategory.electronics.suggestedZone, "桌面右上角充电区")
        XCTAssertEqual(ItemCategory.trash.suggestedZone, "垃圾袋 / 回收袋")
    }

    func testYOLOClassLabelsMapTelevisionAndClothesToUsefulCategories() {
        XCTAssertEqual(YOLOSegmentationScanService.category(forClassName: "tv"), .electronics)
        XCTAssertEqual(YOLOSegmentationScanService.displayName(forClassName: "tv"), "电视设备")
        XCTAssertEqual(YOLOSegmentationScanService.category(forClassName: "jacket"), .clothes)
        XCTAssertEqual(YOLOSegmentationScanService.displayName(forClassName: "jacket"), "外套")
        XCTAssertEqual(YOLOSegmentationScanService.category(forClassName: "laptop"), .electronics)
    }

    func testYOLOClassLabelsKeepStudyMaterialsDistinct() {
        XCTAssertEqual(YOLOSegmentationScanService.category(forClassName: "notebook"), .books)
        XCTAssertEqual(YOLOSegmentationScanService.displayName(forClassName: "notebook"), "笔记本")
        XCTAssertEqual(YOLOSegmentationScanService.category(forClassName: "worksheet"), .books)
        XCTAssertEqual(YOLOSegmentationScanService.displayName(forClassName: "paper"), "纸张资料")
    }

    func testVisionScanServiceMapsGeneratedOCRTextOnly() async throws {
        let service = VisionScanService()

        let items = try await service.scanImage(.smartPawLabeledDeskImage())
        let categories = Set(items.map(\.category))

        XCTAssertTrue(categories.contains(.books), "Expected Vision OCR to map BOOK into books, got \(items)")
        XCTAssertTrue(categories.contains(.electronics), "Expected Vision OCR to map LAPTOP into electronics, got \(items)")
        XCTAssertTrue(categories.contains(.stationery), "Expected Vision OCR to map PEN into stationery, got \(items)")
    }

    func testVisionScanServiceScansBundledIndependentPhotoWithARHints() async throws {
        let service = VisionScanService()
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))

        let items = try await service.scanImage(image)

        XCTAssertFalse(items.isEmpty, "独立真实照片至少应形成可确认的识别候选，而不是依赖假图。")
        XCTAssertTrue(items.contains { $0.arHint != nil }, "独立真实照片识别结果需要带 AR 区域。")
    }

    func testVisionScanServiceBuildsBaselineForIndependentPhotos() async throws {
        let service = VisionScanService()
        let assetNames = AppSampleAssets.all

        for assetName in assetNames {
            let image = try XCTUnwrap(UIImage(named: assetName), "Missing bundled independent photo: \(assetName)")
            let items = try await service.scanImage(image)

            XCTAssertFalse(items.isEmpty, "\(assetName) 需要形成真实照片识别候选。")
            XCTAssertTrue(items.contains { $0.arHint != nil }, "\(assetName) 需要有真实照片驱动的 AR 区域。")
            XCTAssertTrue(items.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "\(assetName) 不能返回空名称候选。")

            let baseline = items.map {
                "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%|mask:\($0.arMask?.points.count ?? 0)"
            }.joined(separator: "; ")
            print("SMARTPAW_INDEPENDENT_PHOTO_BASELINE \(assetName): \(baseline)")
        }
    }

    func testBundledCoreMLSegmentationModelIsUsableInScanPipeline() async throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "DeepLabV3Int8LUT", withExtension: "mlmodelc"), "Apple DeepLabV3 Core ML 分割模型必须随 App 入包。")

        let service = CoreMLSegmentationScanService()
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))
        let items = try await service.scanImage(image)

        XCTAssertFalse(items.isEmpty)
        XCTAssertTrue(items.contains { $0.arMask?.isRenderable == true }, "Core ML 分割扫描服务需要返回可用于 AR 高亮的 mask。")
    }

    func testYOLOSegmentationModelRecognizesIndependentPhotoWithInstanceMasks() async throws {
        XCTAssertNotNil(Bundle.main.url(forResource: "yolo11n-seg", withExtension: "mlmodelc"), "YOLO11n-seg 实例分割模型必须随 App 入包，不能只依赖系统框选。")

        let service = YOLOSegmentationScanService()
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))
        let items = try await service.scanImage(image)

        XCTAssertTrue(items.contains { ($0.confidence >= 0.25) && ($0.arMask?.hasRaster == true) }, "YOLO 主链路需要在独立真实照片上自动产生 raster mask。")
        print("SMARTPAW_YOLO_INDEPENDENT_PHOTO \(AppSampleAssets.messyDesk): \(items.map { "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%|mask:\($0.arMask?.points.count ?? 0)" }.joined(separator: "; "))")
    }

    func testYOLOLiveScanUsesStableRealtimeCandidates() async throws {
        let service = YOLOSegmentationScanService()
        let kitchenURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/EvaluationScanTests/eval-real-02-kitchen-counter.jpg")
        let samples: [(String, UIImage)] = [
            (AppSampleAssets.messyDesk, try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))),
            ("eval-real-02-kitchen-counter", try XCTUnwrap(UIImage.downsampled(data: Data(contentsOf: kitchenURL))))
        ]

        for (name, image) in samples {
            let items = await service.scanLiveImage(image)
            XCTAssertFalse(items.isEmpty, "实时扫描路径需要在独立真实照片上形成至少一个候选。")
            XCTAssertTrue(items.allSatisfy { $0.arHint != nil }, "实时扫描候选必须带稳定的定位框。")
            print("SMARTPAW_LIVE_PHOTO \(name): \(items.map { "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%|mask:\($0.arMask?.points.count ?? 0)" }.joined(separator: "; "))")
        }
    }

    func testYOLOSegmentationModelRecognizesNewNonVideoImages() async throws {
        let service = YOLOSegmentationScanService()
        let samples = [
            ("external-cluttered-study-pexels", "jpg", 2, true),
            ("external-messy-desk-note", "png", 8, true),
            ("external-trash-room-imweb", "jpg", 1, true)
        ]
        let requestedSample = ProcessInfo.processInfo.environment["SMARTPAW_EXTERNAL_IMAGE"]
        let selectedSamples = requestedSample.map { requested in
            samples.filter { $0.0 == requested }
        } ?? samples
        let requestedSampleName = requestedSample ?? ""
        XCTAssertFalse(selectedSamples.isEmpty, "Unknown SMARTPAW_EXTERNAL_IMAGE: \(requestedSampleName)")

        for (name, ext, minimumMaskCount, requiresRasterMask) in selectedSamples {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: ext), "Missing external non-video test image \(name).\(ext)")
            let data = try Data(contentsOf: url)
            let image = try XCTUnwrap(UIImage.downsampled(data: data), "Could not decode external test image \(name).\(ext)")

            let items = try await service.scanImage(image)
            let maskCount = items.filter { $0.arMask?.isRenderable == true }.count
            let boxOnlyItems = items.filter { $0.arMask == nil }
            XCTAssertGreaterThanOrEqual(maskCount, minimumMaskCount, "\(name) should produce automatic masks from a new non-video image, got \(items)")
            if requiresRasterMask {
                XCTAssertTrue(
                    items.filter { $0.arMask != nil }.allSatisfy { $0.arMask?.hasRaster == true },
                    "\(name) segmentation candidates must return raster masks, not polygon fallbacks"
                )
                XCTAssertTrue(
                    boxOnlyItems.allSatisfy { $0.arHint != nil },
                    "\(name) detection-only candidates must carry an AR bounding box"
                )
            }
            print("SMARTPAW_YOLO_EXTERNAL_IMAGE \(name): \(items.map { "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%|mask:\($0.arMask?.points.count ?? 0)" }.joined(separator: "; "))")
        }
    }

    func testYOLOSegmentationBookshelfBookHasMaskAndLabel() async throws {
        let imageURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/EvaluationScanTests/eval-real-04-bookshelf.jpg")
        let image = try XCTUnwrap(UIImage.downsampled(data: Data(contentsOf: imageURL)))
        let items = try await YOLOSegmentationScanService().scanImage(image)
        let book = try XCTUnwrap(
            items.first { $0.category == .books && $0.name.contains("书本") },
            "Bookshelf scan must surface the detected book label."
        )
        XCTAssertTrue(
            book.arMask?.hasRaster == true,
            "A book label must be shown together with its real segmentation mask, not as a box-only label."
        )
        XCTAssertGreaterThan(
            book.arMask?.rasterPixelCount ?? 0,
            5,
            "The book mask must contain real foreground pixels."
        )
    }

    func testYOLOSegmentationOverlaySuppressesFurnitureAndDuplicateBookTags() async throws {
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))
        let items = try await YOLOSegmentationScanService().scanImage(image)

        XCTAssertFalse(items.contains { $0.name == "椅子" }, "Furniture should not be shown as a storage-item tag.")
        XCTAssertLessThanOrEqual(
            items.filter { $0.category == .books }.count,
            1,
            "One grouped-books mask should produce one readable book tag."
        )
    }

    func testYOLOSegmentationEvaluationDatasetReportsScenarioHitRate() async throws {
        let manifestPath = ProcessInfo.processInfo.environment["SMARTPAW_EVAL_DATASET"]
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
            ?? URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/EvaluationScanTests/evaluation-dataset.json")
                .path
        let manifestURL = URL(fileURLWithPath: manifestPath)
        let samples = try JSONDecoder().decode([EvaluationScanSample].self, from: Data(contentsOf: manifestURL))
        XCTAssertGreaterThanOrEqual(samples.count, 10, "评测集至少需要 10 张左右的图片，避免只针对单张照片调参。")

        let service = YOLOSegmentationScanService()
        var hitCount = 0
        var usableMaskSampleCount = 0
        var totalMaskCount = 0
        var totalConfidence: Double = 0
        var totalItemCount = 0

        for sample in samples {
            let data = try Data(contentsOf: URL(fileURLWithPath: sample.file))
            let image = try XCTUnwrap(UIImage.downsampled(data: data), "Could not decode evaluation image \(sample.id)")
            let items = try await service.scanImage(image)
            let categories = Set(items.map(\.category))
            let expectedCategories = Set(sample.expected.compactMap(EvaluationScanSample.category(for:)))
            let hit = !categories.isDisjoint(with: expectedCategories)
            let masks = items.compactMap(\.arMask).filter(\.hasRaster)
            let coverages = masks.map(\.rasterCoverage)
            let averageConfidence = items.isEmpty ? 0 : items.map(\.confidence).reduce(0, +) / Double(items.count)

            if hit { hitCount += 1 }
            if !masks.isEmpty { usableMaskSampleCount += 1 }
            totalMaskCount += masks.count
            totalConfidence += items.map(\.confidence).reduce(0, +)
            totalItemCount += items.count

            let coverageRange: String
            if let minCoverage = coverages.min(), let maxCoverage = coverages.max() {
                coverageRange = "\(String(format: "%.3f", minCoverage))-\(String(format: "%.3f", maxCoverage))"
            } else {
                coverageRange = "none"
            }
            let itemSummary = items.map {
                "\($0.name)|\($0.category.rawValue)|\(Int($0.confidence * 100))%|mask:\($0.arMask?.points.count ?? 0)"
            }.joined(separator: "; ")

            XCTAssertFalse(items.isEmpty, "\(sample.id) should produce at least one candidate item.")
            XCTAssertTrue(masks.allSatisfy { $0.rasterCoverage > 0.001 && $0.rasterCoverage < 0.85 }, "\(sample.id) masks should not be empty or whole-screen overlays.")
            print("SMARTPAW_EVAL_SAMPLE \(sample.id)|hit:\(hit ? "yes" : "no")|label:\(sample.label)|expected:\(sample.expected.joined(separator: ","))|items:\(items.count)|masks:\(masks.count)|avg_conf:\(Int(averageConfidence * 100))%|coverage:\(coverageRange)|\(itemSummary)")
        }

        let hitRate = Double(hitCount) / Double(samples.count)
        let usableMaskRate = Double(usableMaskSampleCount) / Double(samples.count)
        let averageItems = Double(totalItemCount) / Double(samples.count)
        let averageMasks = Double(totalMaskCount) / Double(samples.count)
        let averageConfidence = totalItemCount == 0 ? 0 : totalConfidence / Double(totalItemCount)

        XCTAssertGreaterThanOrEqual(hitRate, 0.60, "10 图评测集场景类别命中率不能太低。")
        XCTAssertGreaterThanOrEqual(usableMaskRate, 0.70, "多数评测图需要产生可展示的 raster mask。")
        print("SMARTPAW_EVAL_SUMMARY samples:\(samples.count)|hit_rate:\(Int(hitRate * 100))%|usable_mask_rate:\(Int(usableMaskRate * 100))%|avg_items:\(String(format: "%.1f", averageItems))|avg_masks:\(String(format: "%.1f", averageMasks))|avg_conf:\(Int(averageConfidence * 100))%")
    }

    func testYOLOSegmentationObjectLevelEvaluationReportsTargetRecallAndLocalization() async throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/EvaluationScanTests/object-evaluation-dataset.json")
        let samples = try JSONDecoder().decode([ObjectEvaluationSample].self, from: Data(contentsOf: manifestURL))
        XCTAssertGreaterThanOrEqual(samples.count, 3, "对象级评测至少覆盖三张独立真实照片。")
        let requestedSample = ProcessInfo.processInfo.environment["SMARTPAW_OBJECT_EVAL_SAMPLE"]
        let selectedSamples = requestedSample.map { requested in
            samples.filter { $0.id == requested }
        } ?? samples
        let requestedSampleName = requestedSample ?? ""
        XCTAssertFalse(selectedSamples.isEmpty, "Unknown SMARTPAW_OBJECT_EVAL_SAMPLE: \(requestedSampleName)")

        let service = YOLOSegmentationScanService()
        var total = ObjectDetectionMetrics()
        for sample in selectedSamples {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: sample.file))
            let image = try XCTUnwrap(UIImage.downsampled(data: imageData))
            let items = try await service.scanImage(image)
            let candidateSummary = items.map { item in
                let hint = item.arHint
                let confidence = String(format: "%.3f", item.confidence)
                let box = String(format: "%.3f,%.3f,%.3f,%.3f", hint?.x ?? -1, hint?.y ?? -1, hint?.width ?? -1, hint?.height ?? -1)
                return "\(item.name)|\(item.category.rawValue)|\(confidence)|box:\(box)"
            }.joined(separator: "\n")
            let attachment = XCTAttachment(string: candidateSummary)
            attachment.name = "Object candidates - \(sample.id)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let metrics = ObjectDetectionMetrics.evaluate(predictions: items, references: sample.objects, minimumIoU: 0.25)
            total.combine(metrics)
            print("SMARTPAW_OBJECT_EVAL \(sample.id)|matched_targets:\(metrics.truePositives)|missed_targets:\(metrics.falseNegatives)|unmatched_candidates:\(metrics.unmatchedCandidateCount)|target_recall:\(metrics.percent(metrics.recall))%|mean_iou:\(metrics.formatted(metrics.meanIoU))")
        }

        XCTAssertGreaterThan(total.referenceCount, 0)
        XCTAssertEqual(
            total.truePositives,
            total.referenceCount,
            "对象级评测中的每个明确标注目标都必须匹配名称、类别和位置；新增真实样本后请先修复漏检，或用人工复核后的证据更新其参考标注。"
        )
        XCTAssertGreaterThanOrEqual(
            total.meanIoU,
            0.620,
            "对象级目标虽全部匹配，但整体定位质量不能低于当前真实图片基线。"
        )
        // This manifest intentionally labels only clear, storage-relevant targets.
        // It measures target recall and localization. Precision requires exhaustive
        // per-image annotation, so unmatched candidates are reported, not mislabeled
        // as false positives.
        print("SMARTPAW_OBJECT_EVAL_SUMMARY samples:\(samples.count)|annotated_targets:\(total.referenceCount)|candidates:\(total.predictionCount)|matched_targets:\(total.truePositives)|missed_targets:\(total.falseNegatives)|unmatched_candidates:\(total.unmatchedCandidateCount)|target_recall:\(total.percent(total.recall))%|mean_iou:\(total.formatted(total.meanIoU))")
    }

    func testARMaskQualityMetricsMeasureRasterOverlap() throws {
        let predicted = ARMask.testRasterMask(
            width: 4,
            height: 4,
            filledPixels: [0, 1, 4, 5]
        )
        let reference = ARMask.testRasterMask(
            width: 4,
            height: 4,
            filledPixels: [1, 2, 5, 6]
        )

        let metrics = try XCTUnwrap(predicted.qualityMetrics(against: reference))

        XCTAssertEqual(metrics.predictionPixels, 4)
        XCTAssertEqual(metrics.referencePixels, 4)
        XCTAssertEqual(metrics.intersectionPixels, 2)
        XCTAssertEqual(metrics.unionPixels, 6)
        XCTAssertEqual(metrics.predictionCoverage, 0.25, accuracy: 0.001)
        XCTAssertEqual(metrics.intersectionOverUnion, 2.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(metrics.diceCoefficient, 0.5, accuracy: 0.001)
    }

    func testYOLOMasksHaveSaneRasterCoverageForIndependentPhotoQualityGate() async throws {
        let service = YOLOSegmentationScanService()
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))

        let items = try await service.scanImage(image)
        let coverages = items.compactMap(\.arMask).filter(\.hasRaster).map(\.rasterCoverage)

        XCTAssertGreaterThanOrEqual(coverages.count, 3, "独立真实照片需要产生多个可评测 raster mask。")
        XCTAssertTrue(coverages.allSatisfy { $0 > 0.001 }, "自动 mask 不能是空白 raster。")
        XCTAssertTrue(coverages.allSatisfy { $0 < 0.85 }, "自动 mask 不能用接近整屏的 alpha 糊住画面。")
        print("SMARTPAW_MASK_COVERAGE \(AppSampleAssets.messyDesk): \(coverages.map { String(format: "%.3f", $0) }.joined(separator: ", "))")
    }

    func testPlanningServiceUsesRecognizedARHintsForGuideSteps() {
        let service = RuleBasedPlanningService()
        let mask = ARMask(points: [
            ARMaskPoint(x: 0.50, y: 0.32),
            ARMaskPoint(x: 0.72, y: 0.40),
            ARMaskPoint(x: 0.64, y: 0.56),
            ARMaskPoint(x: 0.48, y: 0.50)
        ])
        let items = [
            DetectedItem(name: "书本", category: .books, confidence: 0.9, arHint: ARHint(x: 0.62, y: 0.42, width: 0.24, height: 0.18), arMask: mask),
            DetectedItem(name: "笔", category: .stationery, confidence: 0.88, arHint: ARHint(x: 0.28, y: 0.68, width: 0.20, height: 0.14))
        ]

        let plan = service.makePlan(for: DemoData.spaces[0], selectedItems: items, style: .quickReset, timeBudget: .ten)

        assertHint(plan.steps.first?.arHint, approximatelyEquals: items[0].arHint)
        XCTAssertEqual(plan.steps.first?.arMask, mask)
        assertHint(plan.steps.last?.arHint, approximatelyEquals: ARHint(x: 0.28, y: 0.68, width: 0.20, height: 0.16))
    }

    func testPlanningStepKeepsMaskAndHintFromTheSameAnchorItem() {
        let service = RuleBasedPlanningService()
        let lowerConfidenceMask = ARMask(points: [
            ARMaskPoint(x: 0.10, y: 0.10), ARMaskPoint(x: 0.26, y: 0.10),
            ARMaskPoint(x: 0.26, y: 0.26), ARMaskPoint(x: 0.10, y: 0.26)
        ])
        let strongestMask = ARMask(points: [
            ARMaskPoint(x: 0.68, y: 0.52), ARMaskPoint(x: 0.88, y: 0.52),
            ARMaskPoint(x: 0.88, y: 0.72), ARMaskPoint(x: 0.68, y: 0.72)
        ])
        let strongestHint = ARHint(x: 0.78, y: 0.62, width: 0.20, height: 0.20)
        let items = [
            DetectedItem(name: "书本/资料", category: .books, confidence: 0.61, arHint: ARHint(x: 0.18, y: 0.18, width: 0.16, height: 0.16), arMask: lowerConfidenceMask),
            DetectedItem(name: "笔记本", category: .books, confidence: 0.93, arHint: strongestHint, arMask: strongestMask)
        ]

        let step = service.makePlan(for: DemoData.spaces[0], selectedItems: items, style: .quickReset, timeBudget: .five).steps[0]

        assertHint(step.arHint, approximatelyEquals: strongestHint)
        XCTAssertEqual(step.arMask, strongestMask)
        XCTAssertEqual(Set(step.itemIDs), Set(items.map(\.id)))
    }

    func testDrinkwarePlanDoesNotDescribeCupAsStorageTool() {
        let service = RuleBasedPlanningService()
        let cup = DetectedItem(name: "杯子", category: .tools, confidence: 0.91)
        let plan = service.makePlan(for: DemoData.spaces[0], selectedItems: [cup], style: .quickReset, timeBudget: .five)

        XCTAssertEqual(plan.steps.first?.title, "饮品容器清洗归位")
        XCTAssertTrue(plan.steps.first?.detail.contains("清洗区") == true)
        XCTAssertFalse(plan.steps.first?.detail.contains("手边工具区") == true)
    }

    func testPlanProgressMovesFromZeroToComplete() {
        var plan = StoragePlan(
            style: .warmVisible,
            timeBudget: .ten,
            summary: "测试计划",
            toolList: [],
            steps: [
                StorageStep(title: "第一步", detail: "处理书本", zone: "书架", arHint: ARHint(x: 0.1, y: 0.1, width: 0.2, height: 0.2), itemIDs: []),
                StorageStep(title: "第二步", detail: "处理文具", zone: "抽屉", arHint: ARHint(x: 0.2, y: 0.2, width: 0.2, height: 0.2), itemIDs: [])
            ]
        )

        XCTAssertEqual(plan.progress, 0)
        plan.steps[0].status = .done
        XCTAssertEqual(plan.progress, 0.5)
        plan.steps[1].status = .done
        XCTAssertEqual(plan.progress, 1)
    }

    @MainActor
    func testCompletionRequiresAfterPhotoBeforeArchiving() {
        let viewModel = AppViewModel(dependencies: .test)
        let initialCompletedCount = viewModel.completedCount
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.makePlanFromScan()

        guard let activePlan = viewModel.activePlan else {
            XCTFail("Expected active plan")
            return
        }

        for step in activePlan.steps {
            viewModel.completeStep(step.id)
        }

        XCTAssertNotNil(viewModel.activePlan)
        XCTAssertEqual(viewModel.completedCount, initialCompletedCount)

        viewModel.finishActivePlan(afterImage: UIImage.smartPawTestImage())

        XCTAssertNil(viewModel.activePlan)
        XCTAssertEqual(viewModel.completedCount, initialCompletedCount + 1)
        XCTAssertNotNil(viewModel.latestCompletedPlan?.completedAt)
        XCTAssertFalse(viewModel.selectedSpace.afterImageName.isEmpty)
        XCTAssertTrue(viewModel.selectedSpace.hasVerifiedComparison)
    }

    @MainActor
    func testSharingLatestCompletionCreatesCommunityCase() {
        let viewModel = AppViewModel(dependencies: .test)
        let initialCount = viewModel.communityCases.count
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.makePlanFromScan()

        guard let activePlan = viewModel.activePlan else {
            XCTFail("Expected active plan")
            return
        }

        activePlan.steps.forEach { viewModel.completeStep($0.id) }
        viewModel.finishActivePlan(afterImage: UIImage.smartPawTestImage())
        viewModel.shareLatestCompletion()

        XCTAssertEqual(viewModel.communityCases.count, initialCount + 1)
        XCTAssertEqual(viewModel.communityCases.first?.author, "我")
        XCTAssertEqual(viewModel.communityCases.first?.style, viewModel.latestCompletedPlan?.style)
        XCTAssertEqual(viewModel.communityCases.first?.items.count, DemoData.detectedItems.count)
    }

    @MainActor
    func testScanFailureClearsPreviousItems() async {
        let viewModel = AppViewModel(dependencies: .failingScan)
        viewModel.scannedItems = DemoData.detectedItems

        await viewModel.scanImage(UIImage.smartPawTestImage())

        XCTAssertTrue(viewModel.scannedItems.isEmpty)
    }

    @MainActor
    func testSelectedSpaceCompletedCountDoesNotUseGlobalCompletionCount() {
        let viewModel = AppViewModel(dependencies: .test)
        let secondSpaceID = viewModel.spaces[1].id
        let initialGlobalCount = viewModel.completedCount
        let initialSelectedSpaceCount = viewModel.selectedSpaceCompletedCount
        let initialSecondSpaceCount = viewModel.spaces[1].completedPlans.count
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.makePlanFromScan()

        guard let activePlan = viewModel.activePlan else {
            XCTFail("Expected active plan")
            return
        }

        activePlan.steps.forEach { viewModel.completeStep($0.id) }
        viewModel.finishActivePlan(afterImage: UIImage.smartPawTestImage())

        XCTAssertEqual(viewModel.completedCount, initialGlobalCount + 1)
        XCTAssertEqual(viewModel.selectedSpaceCompletedCount, initialSelectedSpaceCount + 1)

        viewModel.selectSpace(secondSpaceID)

        XCTAssertEqual(viewModel.completedCount, initialGlobalCount + 1)
        XCTAssertEqual(viewModel.selectedSpaceCompletedCount, initialSecondSpaceCount)
    }

    @MainActor
    func testSelectingSpaceClearsScanContextAndRestoresPlanZones() {
        let viewModel = AppViewModel(dependencies: .test)
        let secondSpaceID = viewModel.spaces[1].id
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.capturedImage = UIImage.smartPawTestImage()
        viewModel.referenceImage = UIImage.smartPawTestImage()

        viewModel.selectSpace(secondSpaceID)

        XCTAssertTrue(viewModel.scannedItems.isEmpty)
        XCTAssertNil(viewModel.capturedImage)
        XCTAssertNil(viewModel.referenceImage)
        XCTAssertTrue(viewModel.selectedExecutionZones.isEmpty)
    }

    @MainActor
    func testReplicatingCommunityCaseSelectsAllSourceItemsBeforePlanning() {
        let viewModel = AppViewModel(dependencies: .test)
        let sourceItems = DemoData.detectedItems.map { item in
            var copied = item
            copied.isSelected = false
            return copied
        }
        let communityCase = CommunityCase(
            title: "待复刻方案",
            author: "测试作者",
            style: .hiddenClean,
            likes: 0,
            tags: [],
            items: sourceItems
        )

        viewModel.replicate(communityCase)

        XCTAssertNotNil(viewModel.activePlan)
        XCTAssertTrue(viewModel.scannedItems.allSatisfy(\.isSelected))
    }

    @MainActor
    func testScheduleItemsCanBeToggledAndPersistedInMemory() {
        let viewModel = AppViewModel(dependencies: .test)
        let firstID = viewModel.scheduleItems[0].id
        let initialState = viewModel.scheduleItems[0].isDone

        viewModel.toggleScheduleItem(firstID)

        XCTAssertEqual(viewModel.scheduleItems[0].isDone, !initialState)
    }

    @MainActor
    func testScheduleItemsSupportCreateEditAndDelete() {
        let viewModel = AppViewModel(dependencies: .test)
        let dueDate = Date().addingTimeInterval(7_200)

        viewModel.addScheduleItem(title: "整理衣柜", dueDate: dueDate, note: "先处理当季衣物")
        let created = viewModel.scheduleItems[0]
        XCTAssertEqual(created.title, "整理衣柜")
        XCTAssertEqual(created.dueDate.timeIntervalSince1970, dueDate.timeIntervalSince1970, accuracy: 1)

        var edited = created
        edited.title = "整理上层衣柜"
        viewModel.updateScheduleItem(edited)
        XCTAssertEqual(viewModel.scheduleItems.first(where: { $0.id == created.id })?.title, "整理上层衣柜")

        viewModel.deleteScheduleItem(created.id)
        XCTAssertFalse(viewModel.scheduleItems.contains(where: { $0.id == created.id }))
    }

    @MainActor
    func testCatalogEditingAndCommunityReactionsMutateRealState() {
        let viewModel = AppViewModel(dependencies: .test)
        var item = try! XCTUnwrap(viewModel.catalogItems.first)
        item.name = "已编辑物品"
        item.suggestedZone = "新的归位区"
        viewModel.updateCatalogItem(item)
        XCTAssertEqual(viewModel.catalogItems.first(where: { $0.id == item.id })?.name, "已编辑物品")

        let communityCase = viewModel.communityCases[0]
        let initialLikes = communityCase.likes
        viewModel.toggleCommunityLike(communityCase.id)
        XCTAssertTrue(viewModel.likedCommunityCaseIDs.contains(communityCase.id))
        XCTAssertEqual(viewModel.communityCases.first(where: { $0.id == communityCase.id })?.likes, initialLikes + 1)
        viewModel.toggleCommunityFavorite(communityCase.id)
        XCTAssertTrue(viewModel.favoriteCommunityCaseIDs.contains(communityCase.id))
    }

    @MainActor
    func testCommunityCommentsAndFollowsMutateRealState() {
        let viewModel = AppViewModel(dependencies: .test)
        let communityCase = viewModel.communityCases[0]

        viewModel.addCommunityComment(to: communityCase.id, body: "这套方案很适合我的桌面。")
        XCTAssertEqual(viewModel.commentCount(for: communityCase.id), 1)
        XCTAssertEqual(viewModel.comments(for: communityCase.id).first?.body, "这套方案很适合我的桌面。")

        let comment = viewModel.comments(for: communityCase.id)[0]
        viewModel.toggleCommunityCommentLike(comment.id, in: communityCase.id)
        XCTAssertEqual(viewModel.comments(for: communityCase.id).first?.likes, 1)

        viewModel.toggleCommunityFollow(author: communityCase.author)
        XCTAssertTrue(viewModel.followedCommunityAuthors.contains(communityCase.author))
    }

    @MainActor
    func testPlanningTagsRecommendationModeAndExecutionZonesPersistThroughPlanCreation() {
        let viewModel = AppViewModel(dependencies: .test)
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.togglePlanningTag(ItemCategory.books.rawValue)
        viewModel.recommendationMode = .budget
        viewModel.focusZone = "书桌左侧"

        viewModel.makePlanFromScan()

        XCTAssertEqual(viewModel.recommendationMode, .budget)
        XCTAssertFalse(viewModel.selectedExecutionZones.isEmpty)
        XCTAssertTrue(viewModel.activePlan?.summary.contains("书桌左侧") == true)
    }

    @MainActor
    func testPlanCreationRejectsAnEmptySelection() {
        let viewModel = AppViewModel(dependencies: .test)
        viewModel.scannedItems = DemoData.detectedItems.map { item in
            var item = item
            item.isSelected = false
            return item
        }

        viewModel.makePlanFromScan()

        XCTAssertNil(viewModel.activePlan)
        XCTAssertEqual(viewModel.message, "请至少选择一件需要整理的物品。")
    }

    @MainActor
    func testEmptyPersistedSpacesRecoverWithoutCrashing() {
        let viewModel = AppViewModel(dependencies: .emptySpaces)

        XCTAssertFalse(viewModel.spaces.isEmpty)
        XCTAssertEqual(viewModel.selectedSpace.id, DemoData.spaces[0].id)
    }

    func testLLMSettingsRejectUnsafeOrIncompleteEndpoints() {
        XCTAssertFalse(LLMSettings(isEnabled: true, endpoint: "http://example.com/v1/responses", apiKey: "test-key", model: "model").canRequest)
        XCTAssertFalse(LLMSettings(isEnabled: true, endpoint: "https://", apiKey: "test-key", model: "model").canRequest)
        XCTAssertTrue(LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "model").canRequest)
    }

    func testLLMAPIKeyIsExcludedFromPersistedJSON() throws {
        let settings = LLMSettings(
            isEnabled: true,
            endpoint: "https://example.com/v1/responses",
            apiKey: "super-secret-key",
            model: "model"
        )

        let json = try XCTUnwrap(String(data: JSONEncoder().encode(settings), encoding: .utf8))

        XCTAssertFalse(json.contains("super-secret-key"))
        XCTAssertFalse(json.contains("apiKey"))
    }

    func testJSONStorageRecoversWhenPrimaryFileIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appendingPathComponent("state.json")
        let backupURL = stateURL.deletingPathExtension().appendingPathExtension("backup.json")
        let expected = DemoData.snapshot
        try JSONEncoder().encode(expected).write(to: backupURL)

        let restored = try JSONStorageStore(
            stateURL: stateURL,
            credentialStore: InMemoryCredentialStore()
        ).loadState()

        XCTAssertEqual(restored?.spaces.map(\.id), expected.spaces.map(\.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: stateURL.path))
    }

    func testJSONStorageDoesNotReplaceNewKeychainKeyWithLegacyBackupKey() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appendingPathComponent("state.json")
        let backupURL = stateURL.deletingPathExtension().appendingPathExtension("backup.json")
        let cleanData = try JSONEncoder().encode(DemoData.snapshot)
        try cleanData.write(to: stateURL)
        try legacySnapshotData(apiKey: "legacy-key").write(to: backupURL)
        let credentials = InMemoryCredentialStore(apiKey: "new-key")

        _ = try JSONStorageStore(stateURL: stateURL, credentialStore: credentials).loadState()

        XCTAssertEqual(credentials.loadAPIKey(), "new-key")
        let sanitizedBackup = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertFalse(sanitizedBackup.contains("legacy-key"))
        XCTAssertFalse(sanitizedBackup.contains("apiKey"))
    }

    @MainActor
    func testResetStopsWhenCredentialDeletionFails() {
        let credentials = InMemoryCredentialStore(apiKey: "existing-key", allowsDeletion: false)
        let dependencies = AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: credentials
        )
        let viewModel = AppViewModel(dependencies: dependencies)
        viewModel.selectedStyle = .warmVisible

        viewModel.resetDemo()

        XCTAssertEqual(viewModel.selectedStyle, .warmVisible)
        XCTAssertEqual(credentials.loadAPIKey(), "existing-key")
        XCTAssertEqual(viewModel.message, "API Key 无法从系统钥匙串删除，未执行数据重置。")
    }

    @MainActor
    func testLatestImageRecognitionWinsWhenScansFinishOutOfOrder() async {
        let viewModel = AppViewModel(dependencies: .outOfOrderScan)
        let firstImage = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in }
        let secondImage = UIGraphicsImageRenderer(size: CGSize(width: 25, height: 25)).image { _ in }

        let first = Task { await viewModel.scanImage(firstImage) }
        try? await Task.sleep(nanoseconds: 20_000_000)
        let second = Task { await viewModel.scanImage(secondImage) }
        await first.value
        await second.value

        XCTAssertEqual(viewModel.scannedItems.first?.name, "second")
        XCTAssertEqual(viewModel.capturedImage?.size.width, 25)
    }

    @MainActor
    func testRoomPlanObjectsAreImportedIntoCurrentSpace() {
        let viewModel = AppViewModel(dependencies: .test)
        let initialCount = viewModel.catalogItems.count

        viewModel.importRoomPlanObjects(["table", "chair", "television"])

        XCTAssertEqual(viewModel.catalogItems.count, initialCount + 3)
        XCTAssertTrue(viewModel.scannedItems.contains { $0.name == "电视设备" })
        XCTAssertTrue(viewModel.scannedItems.contains { $0.name == "桌面区域" })
    }

    func testDemoDataDoesNotPresentIndependentPhotosAsVerifiedComparison() {
        let names = DemoData.spaces.flatMap { [$0.beforeAssetName, $0.afterAssetName] }
            + DemoData.communityCases.flatMap { [$0.beforeAssetName, $0.afterAssetName] }
        XCTAssertTrue(names.compactMap { $0 }.allSatisfy { AppSampleAssets.all.contains($0) })
        XCTAssertFalse(names.compactMap { $0 }.contains { $0.hasPrefix("SmartPawVideo") })
        XCTAssertTrue(DemoData.spaces.allSatisfy { !$0.hasVerifiedComparison })
    }

    @MainActor
    func testCloudPlanningCanRefineGeneratedPlan() async {
        let viewModel = AppViewModel(dependencies: .cloudRefining)
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.updateLLMSettings(LLMSettings(
            isEnabled: true,
            endpoint: "https://example.com/v1/responses",
            apiKey: "test-key",
            model: "test-model"
        ))

        await viewModel.makePlanFromScanUsingCloudIfAvailable()

        XCTAssertEqual(viewModel.activePlan?.summary, "云端优化摘要")
        XCTAssertEqual(viewModel.activePlan?.toolList, ["云端工具"])
        XCTAssertEqual(viewModel.activePlan?.steps.first?.title, "云端步骤")
    }

    @MainActor
    func testReferenceImageAndRecommendationModeReachCloudPlanningContext() async {
        let viewModel = AppViewModel(dependencies: .contextEchoCloud)
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.recommendationMode = .premium
        viewModel.setReferenceImage(.smartPawTestImage())
        viewModel.updateLLMSettings(LLMSettings(
            isEnabled: true,
            endpoint: "https://example.com/v1/responses",
            apiKey: "test-key",
            model: "test-model"
        ))

        await viewModel.makePlanFromScanUsingCloudIfAvailable()

        XCTAssertEqual(viewModel.activePlan?.summary, "专业闭环|有参考图")
    }
}

private func assertHint(_ actual: ARHint?, approximatelyEquals expected: ARHint?, file: StaticString = #filePath, line: UInt = #line) {
    guard let actual, let expected else {
        XCTFail("Expected both AR hints to exist", file: file, line: line)
        return
    }
    XCTAssertEqual(actual.x, expected.x, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(actual.y, expected.y, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(actual.width, expected.width, accuracy: 0.001, file: file, line: line)
    XCTAssertEqual(actual.height, expected.height, accuracy: 0.001, file: file, line: line)
}

private func legacySnapshotData(apiKey: String) throws -> Data {
    let cleanData = try JSONEncoder().encode(DemoData.snapshot)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: cleanData) as? [String: Any])
    var settings = try XCTUnwrap(object["llmSettings"] as? [String: Any])
    settings["apiKey"] = apiKey
    object["llmSettings"] = settings
    return try JSONSerialization.data(withJSONObject: object)
}

private extension ARMask {
    static func testRasterMask(width: Int, height: Int, filledPixels: Set<Int>) -> ARMask {
        let alpha = (0..<(width * height)).map { index in
            UInt8(filledPixels.contains(index) ? 255 : 0)
        }
        return ARMask(points: [], rasterWidth: width, rasterHeight: height, rasterAlpha: Data(alpha))
    }
}

private extension AppDependencies {
    static var test: AppDependencies {
        AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    static var failingScan: AppDependencies {
        AppDependencies(
            scanService: FailingScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    static var cloudRefining: AppDependencies {
        AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: TestCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    static var contextEchoCloud: AppDependencies {
        AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: ContextEchoCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    static var emptySpaces: AppDependencies {
        AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: EmptySpacesStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }

    static var outOfOrderScan: AppDependencies {
        AppDependencies(
            scanService: OutOfOrderScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: InMemoryStorageStore(),
            credentialStore: InMemoryCredentialStore()
        )
    }
}

private final class InMemoryCredentialStore: CredentialStore {
    private var apiKey: String?
    private let allowsDeletion: Bool

    init(apiKey: String? = nil, allowsDeletion: Bool = true) {
        self.apiKey = apiKey
        self.allowsDeletion = allowsDeletion
    }

    func loadAPIKey() -> String? { apiKey }

    func saveAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed.isEmpty ? nil : trimmed
        return true
    }

    func deleteAPIKey() -> Bool {
        guard allowsDeletion else { return false }
        apiKey = nil
        return true
    }
}

private struct FailingScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        throw ScanError.noRecognizedContent
    }
}

private struct PassthroughCloudPlanningService: CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        plan
    }
}

private struct TestCloudPlanningService: CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        var refined = plan
        refined.summary = "云端优化摘要"
        refined.toolList = ["云端工具"]
        refined.steps[0].title = "云端步骤"
        return refined
    }
}

private struct ContextEchoCloudPlanningService: CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        var refined = plan
        refined.summary = "\(context.recommendationMode.rawValue)|\(context.referenceImageData == nil ? "无参考图" : "有参考图")"
        return refined
    }
}

private struct EmptySpacesStore: StorageStore {
    func loadState() throws -> AppStateSnapshot? {
        AppStateSnapshot(
            spaces: [],
            achievements: DemoData.achievements,
            communityCases: DemoData.communityCases,
            scheduleItems: DemoData.scheduleItems
        )
    }

    func saveState(_ snapshot: AppStateSnapshot) throws {}
}

private struct OutOfOrderScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        let isFirst = image.size.width < 25
        try await Task.sleep(nanoseconds: isFirst ? 200_000_000 : 10_000_000)
        return [DetectedItem(name: isFirst ? "first" : "second", category: .tools, confidence: 1)]
    }
}

private struct EvaluationScanSample: Decodable {
    let id: String
    let file: String
    let label: String
    let expected: [String]

    static func category(for rawName: String) -> ItemCategory? {
        switch rawName {
        case "books": .books
        case "electronics": .electronics
        case "stationery": .stationery
        case "clothes": .clothes
        case "toys": .toys
        case "trash": .trash
        case "tools": .tools
        default: nil
        }
    }
}

private struct ObjectEvaluationSample: Decodable {
    let id: String
    let file: String
    let objects: [ObjectReference]
}

private struct ObjectReference: Decodable {
    let label: String
    let category: String
    let nameTokens: [String]
    let box: ObjectEvaluationBox

    var itemCategory: ItemCategory? {
        EvaluationScanSample.category(for: category)
    }
}

private struct ObjectEvaluationBox: Decodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

private struct ObjectDetectionMetrics {
    private(set) var truePositives = 0
    private(set) var falseNegatives = 0
    private(set) var predictionCount = 0
    private(set) var referenceCount = 0
    private var matchedIoUSum = 0.0

    var recall: Double { referenceCount == 0 ? 0 : Double(truePositives) / Double(referenceCount) }
    var meanIoU: Double { truePositives == 0 ? 0 : matchedIoUSum / Double(truePositives) }
    var unmatchedCandidateCount: Int { predictionCount - truePositives }

    static func evaluate(predictions: [DetectedItem], references: [ObjectReference], minimumIoU: Double) -> ObjectDetectionMetrics {
        var metrics = ObjectDetectionMetrics(
            predictionCount: predictions.count,
            referenceCount: references.count
        )
        var unmatchedPredictionIndices = Set(predictions.indices)
        for reference in references {
            guard let expectedCategory = reference.itemCategory else {
                XCTFail("Unknown object-evaluation category: \(reference.category)")
                continue
            }
            let candidates = unmatchedPredictionIndices.compactMap { index -> (Int, Double)? in
                let prediction = predictions[index]
                guard prediction.category == expectedCategory,
                      reference.nameTokens.contains(where: prediction.name.contains),
                      let hint = prediction.arHint
                else { return nil }
                let iou = boxIoU(hint, reference.box.rect)
                return iou >= minimumIoU ? (index, iou) : nil
            }
            if let match = candidates.max(by: { $0.1 < $1.1 }) {
                unmatchedPredictionIndices.remove(match.0)
                metrics.truePositives += 1
                metrics.matchedIoUSum += match.1
            } else {
                metrics.falseNegatives += 1
            }
        }
        return metrics
    }

    mutating func combine(_ other: ObjectDetectionMetrics) {
        truePositives += other.truePositives
        falseNegatives += other.falseNegatives
        predictionCount += other.predictionCount
        referenceCount += other.referenceCount
        matchedIoUSum += other.matchedIoUSum
    }

    func percent(_ value: Double) -> Int { Int((value * 100).rounded()) }
    func formatted(_ value: Double) -> String { String(format: "%.3f", value) }

    private static func boxIoU(_ hint: ARHint, _ reference: CGRect) -> Double {
        let prediction = CGRect(
            x: hint.x - hint.width / 2,
            y: hint.y - hint.height / 2,
            width: hint.width,
            height: hint.height
        )
        let intersection = prediction.intersection(reference)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let union = prediction.width * prediction.height + reference.width * reference.height - intersectionArea
        return union > 0 ? Double(intersectionArea / union) : 0
    }
}

private extension UIImage {
    static func smartPawTestImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        return renderer.image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
    }

    static func smartPawLabeledDeskImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 720, height: 420))
        return renderer.image { context in
            UIColor(white: 0.96, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 720, height: 420))

            UIColor(red: 0.87, green: 0.92, blue: 0.96, alpha: 1).setFill()
            context.fill(CGRect(x: 64, y: 52, width: 250, height: 130))
            context.fill(CGRect(x: 382, y: 52, width: 260, height: 130))
            context.fill(CGRect(x: 64, y: 238, width: 578, height: 90))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 54),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            "BOOK".draw(in: CGRect(x: 64, y: 86, width: 250, height: 72), withAttributes: attributes)
            "LAPTOP".draw(in: CGRect(x: 382, y: 86, width: 260, height: 72), withAttributes: attributes)
            "PEN".draw(in: CGRect(x: 64, y: 254, width: 578, height: 72), withAttributes: attributes)
        }
    }
}
