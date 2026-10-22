import CryptoKit
import UIKit
import XCTest
@testable import SmartPaw

final class CloudVisionParsingTests: XCTestCase {
    func testPreviewPromptPreservesInstancesAndZoneBoundary() {
        let prompt = StoragePreviewPrompt.make(planName: "桌面", goal: "整齐", changes: ["文具归位"],
                                               itemNames: ["杯子", "杯子", "笔"], focusZone: "桌面右侧文具区")
        XCTAssertTrue(prompt.contains("杯子 × 2"))
        XCTAssertTrue(prompt.contains("区域外的物品与空间位置保持不变"))
        XCTAssertTrue(prompt.contains("不能靠删除物品制造整洁"))
        XCTAssertTrue(prompt.contains("不要扩图、裁切"))
    }

    func testPreviewRejectsChangedFrameAndCompositesOnlyChosenRegion() throws {
        func png(_ color: UIColor, width: CGFloat = 80, height: CGFloat = 80) throws -> Data {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
                color.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }.pngData())
        }
        func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
            let crop = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
            var bytes = [UInt8](repeating: 0, count: 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return bytes
        }
        let source = try png(.red)
        let generated = try png(.blue)
        let region = try XCTUnwrap(ImagePreviewRegion(x: 0, y: 0, width: 0.5, height: 0.5))
        let output = try StoragePreviewImage.validatedOutput(generated, source: source, region: region)
        let image = try XCTUnwrap(UIImage(data: output)?.cgImage)
        XCTAssertEqual(try pixel(image, x: 10, y: 10), [0, 0, 255, 255])
        for point in [(60, 10), (10, 60), (60, 60), (79, 79), (41, 1)] {
            XCTAssertEqual(try pixel(image, x: point.0, y: point.1), [255, 0, 0, 255])
        }
        XCTAssertEqual(try StoragePreviewImage.validatedOutput(generated, source: source, region: nil), generated)
        XCTAssertThrowsError(try StoragePreviewImage.validatedOutput(png(.blue, width: 120, height: 80), source: source, region: nil)) {
            XCTAssertEqual($0 as? ImageGenerationError, .aspectRatioChanged)
        }
        XCTAssertNil(ImagePreviewRegion(x: -0.1, y: 0, width: 0.5, height: 0.5))
        XCTAssertNil(ImagePreviewRegion(x: 0.8, y: 0, width: 0.5, height: 0.5))
        XCTAssertNil(ImagePreviewRegion(x: 0, y: 0, width: .nan, height: 0.5))
    }

    func testPreviewSizeUsesOriginalAspectRatio() throws {
        func jpeg(_ width: CGFloat, _ height: CGFloat) throws -> Data {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
                .image { _ in }.jpegData(compressionQuality: 0.8))
        }
        XCTAssertEqual(StoragePreviewPrompt.preferredSize(for: try jpeg(300, 200), configured: "1024x1024", model: "gpt-image-2"), "1536x1024")
        XCTAssertEqual(StoragePreviewPrompt.preferredSize(for: try jpeg(200, 300), configured: "1024x1024", model: "gpt-image-2"), "1024x1536")
        XCTAssertEqual(StoragePreviewPrompt.preferredSize(for: try jpeg(200, 200), configured: "1024x1024", model: "gpt-image-2"), "1024x1024")
    }

    /// One opt-in real edit of an AI development image using the production prompt/service.
    func testAIImagePreviewFromSavedRecognition() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SMARTPAW_RUN_AI_PREVIEW"] == "1",
              let imagePath = environment["SMARTPAW_RECOGNITION_IMAGE_PATH"],
              let configPath = environment["SMARTPAW_IMAGE_EDIT_CONFIG_PATH"],
              let reportPath = environment["SMARTPAW_RECOGNITION_REPORT_PATH"] else {
            throw XCTSkip("Explicit AI-image preview edit opt-in is required.")
        }
        let input = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let inputImage = try XCTUnwrap(UIImage.downsampled(data: input))
        let inputJPEG = try XCTUnwrap(inputImage.jpegData(compressionQuality: 0.84))
        let reportURL = URL(fileURLWithPath: reportPath)
        let comparison = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: reportURL)) as? [String: Any])
        let items = try XCTUnwrap(comparison["cloud"] as? [[String: Any]])
        let steps = comparison["plan"] as? [[String: String]] ?? []
        let prompt = StoragePreviewPrompt.make(planName: "AI图实测整理方案", goal: "保留全部物品，文具集中，电子设备方便使用", changes: steps.compactMap { $0["detail"] }, itemNames: items.compactMap { $0["name"] as? String })
        let configData = try Data(contentsOf: URL(fileURLWithPath: configPath))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: configData) as? [String: Any])
        var settings = try JSONDecoder().decode(ImageGenerationSettings.self, from: configData)
        settings.timeoutSeconds = 300
        let start = Date()
        let diagnosticsURL = reportURL.deletingLastPathComponent().appendingPathComponent("generation-response-shape.json")
        let service = OpenAICompatibleImageGenerationService(responseObserver: { shape in
            guard let data = try? JSONSerialization.data(withJSONObject: shape, options: [.prettyPrinted, .sortedKeys]) else { return }
            try? data.write(to: diagnosticsURL, options: .atomic)
        })
        let output = try await service.editImage(ImageGenerationRequest(
            imageData: inputJPEG, prompt: prompt, settings: settings, apiKey: try XCTUnwrap(config["apiKey"] as? String)))
        let resultImage = try XCTUnwrap(UIImage(data: output.imageData))
        let outputURL = reportURL.deletingLastPathComponent().appendingPathComponent("organized-after-ai-input.png")
        try output.imageData.write(to: outputURL, options: .atomic)
        let result: [String: Any] = [
            "source_type": "synthetic_development", "real_holdout": false,
            "edit_requests": 1, "camera_used": false, "elapsed_seconds": Date().timeIntervalSince(start),
            "model": settings.model, "input_sha256": SHA256.hash(data: input).map { String(format: "%02x", $0) }.joined(),
            "output_sha256": SHA256.hash(data: output.imageData).map { String(format: "%02x", $0) }.joined(),
            "input_width": inputImage.cgImage?.width ?? 0, "input_height": inputImage.cgImage?.height ?? 0,
            "output_width": resultImage.cgImage?.width ?? 0, "output_height": resultImage.cgImage?.height ?? 0,
            "requested_size": StoragePreviewPrompt.preferredSize(for: inputJPEG, configured: settings.size, model: settings.model),
            "output_decoded": true, "fidelity_status": "PENDING_VISUAL_REVIEW", "prompt": prompt
        ]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            .write(to: reportURL.deletingLastPathComponent().appendingPathComponent("generation-result.json"), options: .atomic)
        print("SMARTPAW_AI_PREVIEW editRequests=1 decoded=true fidelityReview=pending cameraUsed=false")
    }

    /// Reuses the completed visual response; no camera, recognition or edit request.
    func testSavedAIRecognitionPlanCoversEveryCandidateOffline() throws {
        guard let reportPath = ProcessInfo.processInfo.environment["SMARTPAW_RECOGNITION_REPORT_PATH"] else {
            throw XCTSkip("Opt in with the completed AI comparison report.")
        }
        let reportURL = URL(fileURLWithPath: reportPath)
        let report = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: reportURL)) as? [String: Any])
        let saved = try XCTUnwrap(report["cloud"] as? [[String: Any]])
        let items = try saved.map { object in
            DetectedItem(name: try XCTUnwrap(object["name"] as? String),
                         category: try XCTUnwrap(ItemCategory(rawValue: try XCTUnwrap(object["category"] as? String))), confidence: 0.9)
        }
        let space = StorageSpace(name: "AI图离线方案复验", subtitle: "", beforeImageName: "", afterImageName: "", detectedItems: items)
        let plan = RuleBasedPlanningService().makePlan(for: space, selectedItems: items, style: .warmVisible, timeBudget: .ten,
                                                      goal: "整理桌面且保留所有物品", focusZone: "桌面")
        XCTAssertEqual(Set(plan.steps.flatMap(\.itemIDs)), Set(items.map(\.id)))
        XCTAssertEqual(plan.steps.flatMap(\.itemIDs).count, items.count)
        for item in items { XCTAssertTrue(plan.steps.contains { $0.detail.contains(item.name) }) }
        let output: [String: Any] = [
            "source_type": "synthetic_development", "real_holdout": false, "network_requests": 0, "camera_used": false,
            "candidate_count": items.count, "planned_item_count": plan.steps.flatMap(\.itemIDs).count,
            "unplanned_item_count": Set(items.map(\.id)).subtracting(plan.steps.flatMap(\.itemIDs)).count,
            "steps": plan.steps.map { ["title": $0.title, "detail": $0.detail, "zone": $0.zone, "item_count": $0.itemIDs.count] }
        ]
        try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
            .write(to: reportURL.deletingLastPathComponent().appendingPathComponent("plan-coverage-offline.json"), options: .atomic)
        print("SMARTPAW_AI_OFFLINE_PLAN candidates=\(items.count) planned=\(plan.steps.flatMap(\.itemIDs).count) requests=0")
    }

    func testResponsesParserKeepsAllOutputTextParts() throws {
        let body = #"{"output":[{"content":[{"text":"{\"items\":"},{"text":"[]}"}]}]}"#
        let text = try CloudVisionRecognitionService.responseText(from: Data(body.utf8), chatCompletions: false)
        XCTAssertTrue(try CloudVisionRecognitionService.validatedItems(from: text).isEmpty)
    }

    func testValidatedEmptySceneDiffersFromMalformedResponse() throws {
        XCTAssertTrue(try CloudVisionRecognitionService.validatedItems(from: #"{"items":[]}"#).isEmpty)
        XCTAssertThrowsError(try CloudVisionRecognitionService.validatedItems(from: "cannot read images"))
        XCTAssertThrowsError(try CloudVisionRecognitionService.validatedItems(from: #"{"message":"not supported"}"#))
        XCTAssertThrowsError(try CloudVisionRecognitionService.validatedItems(from: #"{"items":"not a list"}"#))
    }

    /// Explicit opt-in, one real cloud recognition request, no camera or image generation.
    func testAIImageLocalAndCloudComparison() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let imagePath = environment["SMARTPAW_RECOGNITION_IMAGE_PATH"],
              let configPath = environment["SMARTPAW_VISION_CONFIG_PATH"],
              let reportPath = environment["SMARTPAW_RECOGNITION_REPORT_PATH"] else {
            throw XCTSkip("Opt in with an AI development image, private vision config and report path.")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: imagePath))
        let image = try XCTUnwrap(UIImage.downsampled(data: data))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: configPath))) as? [String: Any])
        let settings = LLMSettings(isEnabled: true, endpoint: try XCTUnwrap(config["endpoint"] as? String),
                                   apiKey: try XCTUnwrap(config["apiKey"] as? String), model: try XCTUnwrap(config["model"] as? String),
                                   hasCloudConsent: true)
        let localStart = Date()
        let local = try await YOLOSegmentationScanService().scanImage(image)
        let localDuration = Date().timeIntervalSince(localStart)
        let cloudStart = Date()
        let rawResponseURL = URL(fileURLWithPath: reportPath).deletingPathExtension().appendingPathExtension("raw.txt")
        try FileManager.default.createDirectory(at: rawResponseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let cloud = try await CloudVisionRecognitionService(responseObserver: { text in
            try? text.write(to: rawResponseURL, atomically: true, encoding: .utf8)
        }).recognize(image: image, settings: settings)
        let cloudDuration = Date().timeIntervalSince(cloudStart)
        XCTAssertFalse(cloud.isEmpty, "This AI desk image contains several clearly visible possessions.")
        let router = RecognitionRouter(localScan: { _ in XCTFail("Cloud success must not run local"); return [] },
                                       cloudScan: { _, _ in cloud })
        router.settingsProvider = { settings }
        let result = try await router.scanImage(image)
        XCTAssertEqual(result, cloud)
        let space = StorageSpace(name: "AI图开发测试", subtitle: "synthetic development only", beforeImageName: "", afterImageName: "", detectedItems: result)
        let plan = RuleBasedPlanningService().makePlan(for: space, selectedItems: result, style: .warmVisible,
                                                       timeBudget: .ten, goal: "整理桌面且保留所有物品", focusZone: "桌面")
        XCTAssertFalse(plan.steps.isEmpty)
        func objects(_ items: [DetectedItem]) -> [[String: Any]] {
            items.map { item in
                var object: [String: Any] = ["name": item.name, "category": item.category.rawValue,
                                              "model_score_not_calibrated_probability": item.confidence]
                if let box = item.arHint { object["box"] = ["x": box.x, "y": box.y, "width": box.width, "height": box.height] }
                object["has_local_mask"] = item.arMask != nil
                return object
            }
        }
        let report: [String: Any] = [
            "source_type": "synthetic_development", "real_holdout": false,
            "input_sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            "cloud_model": settings.model, "cloud_host": URL(string: settings.endpoint)?.host ?? "",
            "cloud_requests": 1, "local_duration_seconds": localDuration, "cloud_duration_seconds": cloudDuration,
            "local": objects(local), "cloud": objects(cloud), "production_router": objects(result),
            "plan": plan.steps.map { ["title": $0.title, "detail": $0.detail, "zone": $0.zone] },
            "camera_used": false, "image_generation_requests": 0
        ]
        let reportURL = URL(fileURLWithPath: reportPath)
        try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic)
        print("SMARTPAW_AI_COMPARISON local=\(local.count) cloud=\(cloud.count) planSteps=\(plan.steps.count) cloudRequests=1 cameraUsed=false")
    }

    func testDenseScenePreservesEachVisibleInstanceBeyondTenItems() throws {
        let raw = (0..<18).map { index in
            ["name": "杯子", "category": "饮品", "x": Double(index) / 20,
             "y": 0.4, "width": 0.05, "height": 0.1] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: ["items": raw])
        let items = CloudVisionRecognitionService.items(from: String(decoding: data, as: UTF8.self))
        XCTAssertEqual(items.count, 18)
        XCTAssertEqual(items.map(\.arHint?.x), (0..<18).map { Double($0) / 20 })
        XCTAssertTrue(items.allSatisfy { $0.category == .drinks })
    }

    func testTopLevelArrayAndStringCoordinatesAreAccepted() {
        let array = """
        ```json
        [{"name":"笔记本","category":"书籍","x":0.3,"y":0.4}]
        ```
        """
        XCTAssertEqual(CloudVisionRecognitionService.items(from: array).first?.name, "笔记本")
        let strings = #"{"items":[{"name":"杯子","x":"0.7","y":"0.2"}]}"#
        XCTAssertEqual(CloudVisionRecognitionService.items(from: strings).first?.arHint?.x, 0.7)
    }

    func testFurnitureExcludedWhileDeskPossessionsUseCurrentCategories() {
        let text = #"{"items":[{"name":"书桌"},{"name":"吊灯"},{"name":"台灯"},{"name":"水杯"},{"name":"餐碗"},{"name":"体温计"}]}"#
        let items = CloudVisionRecognitionService.items(from: text)
        XCTAssertEqual(items.map(\.name), ["台灯", "水杯", "餐碗", "体温计"])
        XCTAssertEqual(items.map(\.category), [.decor, .drinks, .kitchen, .health])
    }

    func testMalformedOrUnidentifiableResponseDoesNotInventPossessions() {
        XCTAssertTrue(CloudVisionRecognitionService.items(from: "暂时无法识别").isEmpty)
        XCTAssertTrue(CloudVisionRecognitionService.items(from: #"{"items":[{"name":" "}]}"#).isEmpty)
    }
}
