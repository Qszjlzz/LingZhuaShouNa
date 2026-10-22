import XCTest
import UIKit
import WebKit
import SwiftUI
@testable import SmartPaw

final class ImageGenerationServiceTests: XCTestCase {
    func testGeneratedPreviewCanBeRestoredAfterManagerRecreation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("smartpaw-image-cache-test-\(UUID().uuidString)", isDirectory: true)
        let suite = "SmartPaw.image-cache-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let manager = ImageGenerationManager(documentsDirectory: directory)
        let cacheID = "space-123-plan-456"
        let jpeg = try XCTUnwrap(UIImage.smartPawTestImage().jpegData(compressionQuality: 0.8))
        let prompt = "preserve this room"
        let fingerprintedID = ImageGenerationManager.fingerprintedCacheID(cacheID, imageData: jpeg, prompt: prompt)
        let saved = try manager.persistGeneratedImage(jpeg, cacheID: fingerprintedID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))

        let relaunchedManager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
        XCTAssertEqual(relaunchedManager.cachedPreview(cacheID: cacheID, imageData: jpeg, prompt: prompt)?.path, saved.path)
        XCTAssertNil(relaunchedManager.cachedPreview(cacheID: cacheID, imageData: jpeg, prompt: "a changed goal"))
        XCTAssertNil(relaunchedManager.cachedPreview(cacheID: cacheID, imageData: Data([1, 2, 3]), prompt: prompt))
        XCTAssertNil(relaunchedManager.cachedPreview(cacheID: "another-space-plan", imageData: jpeg, prompt: prompt))
    }

    func testGPTImage2MultipartUsesSupportedFieldsAndJPEG() async throws {
        let image = try XCTUnwrap(UIImage.smartPawTestImage().jpegData(compressionQuality: 0.8))
        let fixture = try makeImageService(statusCode: 200, object: ["data": [["b64_json": image.base64EncodedString()]]]) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-key")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=SmartPaw-") == true)
            let body = Self.requestBody(request)
            let text = String(decoding: body, as: UTF8.self)
            for field in ["model", "prompt", "n", "size", "image"] {
                XCTAssertTrue(text.contains("name=\"\(field)\""), "Missing field \(field)")
            }
            XCTAssertTrue(text.contains("gpt-image-2"))
            XCTAssertTrue(text.contains("test organization prompt"))
            XCTAssertTrue(text.contains("filename=\"space.jpg\""))
            XCTAssertTrue(text.contains("Content-Type: image/jpeg"))
            XCTAssertNotNil(body.range(of: image))
            XCTAssertFalse(text.contains("name=\"quality\""))
            XCTAssertFalse(text.contains("name=\"response_format\""))
        }
        defer { fixture.cleanup() }
        _ = try await fixture.service.editImage(fixture.request(imageData: image))
    }

    func testBase64ResponseReturnsRealImageData() async throws {
        let image = try XCTUnwrap(UIImage.smartPawTestImage().pngData())
        let fixture = try makeImageService(statusCode: 200, object: ["data": [["b64_json": image.base64EncodedString()]]])
        defer { fixture.cleanup() }
        let result = try await fixture.service.editImage(fixture.request(imageData: image))
        XCTAssertEqual(result.imageData, image)
        XCTAssertNotNil(UIImage(data: result.imageData))
    }

    func testHTTPSURLResponseDownloadsImageBytes() async throws {
        let image = try XCTUnwrap(UIImage.smartPawTestImage().pngData())
        let downloadURL = URL(string: "https://smartpaw-image-tests.invalid/\(UUID().uuidString)-download")!
        ImageGenerationURLProtocol.register(url: downloadURL) { request in
            XCTAssertEqual(request.httpMethod, "GET")
            return (HTTPURLResponse(url: downloadURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "image/png"])!, image)
        }
        let endpoint = URL(string: "https://smartpaw-image-tests.invalid/\(UUID().uuidString)")!
        let body = try JSONSerialization.data(withJSONObject: ["data": [["url": downloadURL.absoluteString]]])
        ImageGenerationURLProtocol.register(url: endpoint) { _ in
            (HTTPURLResponse(url: endpoint, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, body)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageGenerationURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            ImageGenerationURLProtocol.unregister(url: endpoint)
            ImageGenerationURLProtocol.unregister(url: downloadURL)
        }
        let service = OpenAICompatibleImageGenerationService(session: session)
        let request = ImageGenerationRequest(imageData: image, prompt: "test", settings: ImageGenerationSettings(
            enabled: true, provider: "test", endpoint: endpoint.absoluteString, model: "gpt-image-2",
            size: "1024x1024", quality: "", responseFormat: "", timeoutSeconds: 30
        ), apiKey: "test-only-key")
        let result = try await service.editImage(request)
        XCTAssertEqual(result.imageData, image)
    }

    func testHTTPFailuresDoNotExposeProviderText() async throws {
        let providerSecret = "upstream-test-key-and-private-photo-prompt"
        for statusCode in [401, 429] {
            let fixture = try makeImageService(statusCode: statusCode, object: ["error": ["message": providerSecret]])
            defer { fixture.cleanup() }
            do {
                _ = try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertEqual(error as? ImageGenerationError, .requestFailed(statusCode: statusCode))
                XCTAssertFalse(error.localizedDescription.contains(providerSecret))
                XCTAssertTrue(error.localizedDescription.contains(statusCode == 401 ? "鉴权" : "限流"))
            }
        }
    }

    func testResponseShapeDiagnosticNeverIncludesProviderContent() async throws {
        let observed = expectation(description: "safe response shape observed")
        let fixture = try makeImageService(statusCode: 200, object: ["error": ["message": "private-key-photo-prompt"], "url": "https://private.invalid/signed-token"], responseObserver: { shape in
            XCTAssertEqual(shape["status"], "200")
            XCTAssertEqual(shape["has_error"], "true")
            XCTAssertEqual(shape["has_data_array"], "false")
            XCTAssertEqual(Set(shape.keys), Set(["status", "response_bytes", "content_type", "has_data_array", "has_error"]))
            XCTAssertFalse(String(describing: shape).contains("private-"))
            observed.fulfill()
        })
        defer { fixture.cleanup() }
        do {
            _ = try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
            XCTFail("Expected invalid response")
        } catch { XCTAssertEqual(error as? ImageGenerationError, .invalidResponse) }
        await fulfillment(of: [observed], timeout: 1)
    }

    func testMalformedResponseNeverReturnsOriginalImage() async throws {
        let fixture = try makeImageService(statusCode: 200, object: ["data": [["b64_json": Data("not an image".utf8).base64EncodedString()]]])
        defer { fixture.cleanup() }
        do {
            _ = try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? ImageGenerationError, .invalidResponse)
        }
    }

    func testTimedOutRequestMapsToSafeTimeoutError() async throws {
        let fixture = makeFailingImageService(error: URLError(.timedOut))
        defer { fixture.cleanup() }
        do {
            _ = try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? ImageGenerationError, .timedOut)
            XCTAssertTrue(error.localizedDescription.contains("超时"))
        }
    }

    func testCancelledRequestMapsToSafeCancellationError() async throws {
        let started = expectation(description: "URLProtocol started the pending image request")
        let fixture = makeHangingImageService { started.fulfill() }
        defer { fixture.cleanup() }
        let operation = Task {
            try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
        }
        await fulfillment(of: [started], timeout: 3)
        operation.cancel()
        do {
            _ = try await operation.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? ImageGenerationError, .cancelled)
            XCTAssertTrue(error.localizedDescription.contains("已取消"))
        }
    }

    func testURLCancelledRequestMapsToSafeCancellationError() async throws {
        let fixture = makeFailingImageService(error: URLError(.cancelled))
        defer { fixture.cleanup() }
        do {
            _ = try await fixture.service.editImage(fixture.request(imageData: Data([0xFF, 0xD8, 0xFF])))
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertEqual(error as? ImageGenerationError, .cancelled)
        }
    }

    private func makeImageService(statusCode: Int, object: [String: Any], responseObserver: (@Sendable ([String: String]) -> Void)? = nil, inspect: ((URLRequest) -> Void)? = nil) throws -> ImageServiceFixture {
        let url = URL(string: "https://smartpaw-image-tests.invalid/\(UUID().uuidString)")!
        let body = try JSONSerialization.data(withJSONObject: object)
        ImageGenerationURLProtocol.register(url: url) { request in
            inspect?(request)
            return (HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, body)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageGenerationURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ImageServiceFixture(url: url, session: session, service: OpenAICompatibleImageGenerationService(session: session, responseObserver: responseObserver))
    }

    private func makeFailingImageService(error: Error) -> ImageServiceFixture {
        let url = URL(string: "https://smartpaw-image-tests.invalid/\(UUID().uuidString)")!
        ImageGenerationURLProtocol.registerFailure(url: url, error: error)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageGenerationURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ImageServiceFixture(url: url, session: session, service: OpenAICompatibleImageGenerationService(session: session))
    }

    private func makeHangingImageService(onStart: @escaping () -> Void) -> ImageServiceFixture {
        let url = URL(string: "https://smartpaw-image-tests.invalid/\(UUID().uuidString)")!
        ImageGenerationURLProtocol.registerHang(url: url, onStart: onStart)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageGenerationURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ImageServiceFixture(url: url, session: session, service: OpenAICompatibleImageGenerationService(session: session))
    }

    private static func requestBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            body.append(contentsOf: buffer.prefix(count))
        }
        return body
    }
}

private struct ImageServiceFixture {
    let url: URL
    let session: URLSession
    let service: OpenAICompatibleImageGenerationService

    func request(imageData: Data) -> ImageGenerationRequest {
        ImageGenerationRequest(imageData: imageData, prompt: "test organization prompt", settings: ImageGenerationSettings(
            enabled: true, provider: "test", endpoint: url.absoluteString, model: "gpt-image-2", size: "1024x1024",
            quality: "unsupported-must-be-omitted", responseFormat: "unsupported-must-be-omitted", timeoutSeconds: 30
        ), apiKey: "test-only-key")
    }

    func cleanup() {
        session.invalidateAndCancel()
        ImageGenerationURLProtocol.unregister(url: url)
    }
}

private final class ImageGenerationURLProtocol: URLProtocol {
    private static let registryLock = NSLock()
    private enum StubResult {
        case response(HTTPURLResponse, Data)
        case failure(Error)
        case hang(() -> Void)
    }
    nonisolated(unsafe) private static var handlers: [URL: (URLRequest) -> StubResult] = [:]

    static func register(url: URL, handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)) {
        registryLock.lock()
        defer { registryLock.unlock() }
        handlers[url] = { request in
            let (response, data) = handler(request)
            return .response(response, data)
        }
    }

    static func registerFailure(url: URL, error: Error) {
        registryLock.lock()
        defer { registryLock.unlock() }
        handlers[url] = { _ in .failure(error) }
    }

    static func registerHang(url: URL, onStart: @escaping () -> Void) {
        registryLock.lock()
        defer { registryLock.unlock() }
        handlers[url] = { _ in .hang(onStart) }
    }

    static func unregister(url: URL) {
        registryLock.lock()
        defer { registryLock.unlock() }
        handlers.removeValue(forKey: url)
    }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "smartpaw-image-tests.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.registryLock.lock()
        let handler = request.url.flatMap { Self.handlers[$0] }
        Self.registryLock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        switch handler(request) {
        case .response(let response, let data):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        case .hang(let onStart):
            onStart()
        }
    }
    override func stopLoading() {}
}

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

    func testFigmaCategoriesMapWithoutFallingBackToTools() {
        XCTAssertEqual(ItemCategory(webValue: "服饰"), .clothes)
        XCTAssertEqual(ItemCategory(webValue: "玩具"), .toys)
        XCTAssertEqual(ItemCategory(webValue: "工具"), .tools)
        for category in [ItemCategory.kitchen, .drinks, .health, .decor] {
            XCTAssertEqual(ItemCategory(webValue: category.rawValue), category)
            XCTAssertNoThrow(try JSONDecoder().decode(ItemCategory.self, from: JSONEncoder().encode(category)))
        }
        XCTAssertNil(ItemCategory(webValue: "未知类别"))
        XCTAssertNil(ItemCategory(webValue: "手动补录"))
    }

    @MainActor
    func testManualItemGroupPersistsAndFailedGroupUpdateRollsBack() throws {
        let storage = FailingWriteStorageStore()
        let dependencies = AppDependencies(
            scanService: EmptyScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: storage,
            credentialStore: InMemoryCredentialStore()
        )
        let viewModel = AppViewModel(dependencies: dependencies)
        XCTAssertTrue(viewModel.addManualItem(name: "陶瓷杯", category: .drinks, suggestedZone: "杯架", forScan: true))
        var item = try XCTUnwrap(viewModel.catalogItems.first(where: { $0.name == "陶瓷杯" }))
        XCTAssertEqual(item.suggestedZone, "杯架")
        XCTAssertEqual(viewModel.scannedItems.first(where: { $0.id == item.id })?.suggestedZone, "杯架")

        item.suggestedZone = "饮品柜"
        storage.failsWrites = true
        XCTAssertFalse(viewModel.updateCatalogItem(item))
        XCTAssertEqual(viewModel.catalogItems.first(where: { $0.id == item.id })?.suggestedZone, "杯架")
        XCTAssertEqual(viewModel.scannedItems.first(where: { $0.id == item.id })?.suggestedZone, "杯架")

        storage.failsWrites = false
        XCTAssertTrue(viewModel.updateCatalogItem(item))
        let relaunched = AppViewModel(dependencies: dependencies)
        XCTAssertEqual(relaunched.catalogItems.first(where: { $0.id == item.id })?.category, .drinks)
        XCTAssertEqual(relaunched.catalogItems.first(where: { $0.id == item.id })?.suggestedZone, "饮品柜")
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

    func testRepeatedPhotoRecognitionOverlappingLiveFramesSurvives() async throws {
        let service = YOLOSegmentationScanService()
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))
        for iteration in 0..<2 {
            async let photoItems = service.scanImage(image)
            async let liveItems = service.scanLiveImage(image)
            let (photo, live) = try await (photoItems, liveItems)
            XCTAssertFalse(photo.isEmpty, "Photo inference failed on iteration \(iteration)")
            XCTAssertFalse(live.isEmpty, "Live inference failed on iteration \(iteration)")
            XCTAssertTrue(photo.allSatisfy { $0.confidence.isFinite })
        }
    }

    /// Opt in via the xctestrun environment; never opens the camera in ordinary test runs.
    /// Uses production bridge/AVFoundation/local inference, with an isolated state store.
    /// The small HTML receiver is a bridge harness, not the React shoot-flow UI.
    @MainActor
    func testHardwareCameraSixCapturesThroughProductionBridge() async throws {
        try await verifyHardwareCameraCaptures(waitAfterEachCapture: true)
    }

    @MainActor
    func testHardwareCameraBurstQueueThroughProductionBridge() async throws {
        try await verifyHardwareCameraCaptures(waitAfterEachCapture: false)
    }

    @MainActor
    private func verifyHardwareCameraCaptures(waitAfterEachCapture: Bool) async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires a connected, unlocked physical iPhone.")
        #else
        guard ProcessInfo.processInfo.environment["SMARTPAW_RUN_CAMERA_HARDWARE"] == "1" else {
            throw XCTSkip("Explicit hardware-camera opt-in is required.")
        }
        let suite = "SmartPaw.hardware-tests.\(UUID().uuidString)"
        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let isolatedDocuments = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedDocuments, withIntermediateDirectories: true)
        defer {
            isolatedDefaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: isolatedDocuments)
        }
        let store = InMemoryStorageStore()
        let dependencies = AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: store, credentialStore: InMemoryCredentialStore()
        )
        let model = AppViewModel(dependencies: dependencies, defaults: isolatedDefaults, documentsDirectory: isolatedDocuments)
        let coordinator = CurrentFigmaMakeWebView.Coordinator(viewModel: model)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(coordinator, name: "smartpaw")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        coordinator.webView = webView
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view.addSubview(webView)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        let previousIdleSetting = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        var savedImages = Set<URL>()
        defer {
            coordinator.stopCaptureWork()
            configuration.userContentController.removeScriptMessageHandler(forName: "smartpaw")
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            UIApplication.shared.isIdleTimerDisabled = previousIdleSetting
            for url in savedImages { try? FileManager.default.removeItem(at: url) }
        }
        webView.loadHTMLString("""
        <html><body><h1>Real camera bridge regression</h1><div id=photos></div><script>
        window.__hardwareResponses={};
        window.__smartPawReceive=function(r){if(r.requestId)window.__hardwareResponses[r.requestId]=r;
        if(r.data&&r.data.preview){var i=document.createElement('img');i.src=r.data.preview;i.width=100;document.getElementById('photos').appendChild(i);}};
        </script></body></html>
        """, baseURL: nil)
        let loadDeadline = Date().addingTimeInterval(15)
        while Date() < loadDeadline {
            if (try? await webView.evaluateJavaScript("typeof window.__smartPawReceive === 'function'")) as? Bool == true { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let receiverType = try await webView.evaluateJavaScript("typeof window.__smartPawReceive") as? String
        XCTAssertEqual(receiverType, "function")
        _ = try await hardwareBridgeRequest(webView, command: "scan.begin")
        let started = try await hardwareBridgeRequest(webView, command: "camera.preview.start", payload: ["x": 0, "y": 0, "width": 390, "height": 500])
        XCTAssertEqual(started["ok"] as? Bool, true, "Real camera must start; permission/lock failures are not a pass.")
        var captureIDs: [String] = []
        for index in 1...6 {
            let id = UUID().uuidString
            captureIDs.append(id)
            let captured = try await hardwareBridgeRequest(webView, command: "camera.capture", payload: ["captureID": id], timeout: 20)
            let preview = try XCTUnwrap(captured["preview"] as? String)
            XCTAssertTrue(preview.hasPrefix("data:image/jpeg;base64,"))
            XCTAssertLessThan(preview.utf8.count, 1_000_000, "Only a thumbnail may cross the bridge.")
            if waitAfterEachCapture {
                _ = try await hardwareBridgeRequest(webView, command: "scan.await", payload: ["captureIDs": captureIDs], timeout: 300)
                XCTAssertFalse(model.isScanning)
                XCTAssertTrue(model.lastScanPersisted)
            }
            // The burst path must not wait on recognition before requesting the next capture.
            let thumbnailData = try XCTUnwrap(Data(base64Encoded: String(preview.dropFirst("data:image/jpeg;base64,".count))))
            let image = try XCTUnwrap(waitAfterEachCapture ? model.capturedImage : UIImage(data: thumbnailData))
            let pixels = try XCTUnwrap(image.cgImage)
            XCTAssertLessThanOrEqual(max(pixels.width, pixels.height), 2048)
            if let url = model.imageURL(for: model.selectedSpace.beforeImageName) { savedImages.insert(url) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "real-camera-\(index)-\(pixels.width)x\(pixels.height)"
            attachment.lifetime = .keepAlways
            add(attachment)
            print("SMARTPAW_HARDWARE_CAPTURE index=\(index) pixels=\(pixels.width)x\(pixels.height) thumbnailBytes=\(preview.utf8.count) items=\(model.scannedItems.count) persisted=\(model.lastScanPersisted)")
        }
        let completed = try await hardwareBridgeRequest(webView, command: "scan.await", payload: ["captureIDs": captureIDs], timeout: 300)
        XCTAssertFalse(model.isScanning)
        XCTAssertTrue(model.lastScanPersisted)
        for id in captureIDs {
            let result = try await hardwareBridgeRequest(webView, command: "scan.results", payload: ["captureID": id])
            XCTAssertEqual(result["ready"] as? Bool, true)
        }
        let completedItems = completed["items"] as? [[String: Any]] ?? []
        print("SMARTPAW_HARDWARE_QUEUE captures=\(captureIDs.count) waitAfterEach=\(waitAfterEachCapture) completedItems=\(completedItems.count) persisted=\(model.lastScanPersisted)")
        let rendered = try await webView.evaluateJavaScript("Array.from(document.images).filter(i=>i.complete&&i.naturalWidth>0).length")
        XCTAssertEqual(rendered as? Int, 6, "WebContent must decode all six real thumbnails.")
        if model.scannedItems.contains(where: \.isSelected) {
            _ = try await hardwareBridgeRequest(webView, command: "plan.generate")
            XCTAssertFalse(try XCTUnwrap(model.activePlan).steps.isEmpty)
            let restored = AppViewModel(dependencies: dependencies, defaults: isolatedDefaults, documentsDirectory: isolatedDocuments)
            XCTAssertEqual(restored.activePlan?.id, model.activePlan?.id)
            print("SMARTPAW_HARDWARE_LOCAL_PLAN steps=\(model.activePlan?.steps.count ?? 0) restored=true")
        } else {
            print("SMARTPAW_HARDWARE_LOCAL_PLAN not_covered=no_selected_detections")
        }
        _ = try await hardwareBridgeRequest(webView, command: "scan.cancel")
        XCTAssertFalse(CameraEngine.shared.isReady)
        #endif
    }

    @MainActor
    private func hardwareBridgeRequest(_ webView: WKWebView, command: String, payload: [String: Any] = [:], timeout: TimeInterval = 30) async throws -> [String: Any] {
        let id = UUID().uuidString
        let request: [String: Any] = ["requestId": id, "command": command, "payload": payload]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: request), as: UTF8.self)
        _ = try await webView.evaluateJavaScript("window.webkit.messageHandlers.smartpaw.postMessage(\(json)); true")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let response = try await webView.evaluateJavaScript("window.__hardwareResponses['\(id)'] || null") as? [String: Any] {
                guard response["status"] as? String == "success" else {
                    throw NSError(domain: "SmartPawHardwareBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(command): \(response["message"] ?? response)"])
                }
                return response["data"] as? [String: Any] ?? [:]
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(domain: "SmartPawHardwareBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(command) timed out"])
    }

    @MainActor
    func testHardwareReactPhotoRetakeDeleteAndLocalPlan() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires a physical iPhone and a lit scene with recognizable objects.")
        #else
        guard ProcessInfo.processInfo.environment["SMARTPAW_RUN_CAMERA_HARDWARE"] == "1" else {
            throw XCTSkip("Explicit hardware-camera opt-in is required.")
        }
        let suite = "SmartPaw.hardware-tests.\(UUID().uuidString)"
        let isolatedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let isolatedDocuments = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedDocuments, withIntermediateDirectories: true)
        defer {
            isolatedDefaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: isolatedDocuments)
        }
        let stateURL = isolatedDocuments.appendingPathComponent("hardware-state.json")
        let credentials = InMemoryCredentialStore()
        func isolatedDependencies() -> AppDependencies {
            AppDependencies(
                scanService: YOLOSegmentationScanService(), planningService: RuleBasedPlanningService(),
                cloudPlanningService: PassthroughCloudPlanningService(),
                storageStore: JSONStorageStore(stateURL: stateURL, credentialStore: credentials),
                credentialStore: credentials)
        }
        func restoredModel(selecting spaceID: UUID? = nil) -> AppViewModel {
            let restored = AppViewModel(dependencies: isolatedDependencies(), defaults: isolatedDefaults,
                                        documentsDirectory: isolatedDocuments)
            // Selection is UI state, not part of AppStateSnapshot. New models select the first space.
            if let spaceID { restored.selectSpace(spaceID) }
            return restored
        }
        func printVerifiedStage(_ message: String) throws {
            guard (testRun?.failureCount ?? 0) == 0 else {
                throw NSError(domain: "SmartPawHardwareUI", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "A preceding assertion failed; stage success is not verified."
                ])
            }
            print(message)
        }
        let model = restoredModel()
        let testSpaceID = try XCTUnwrap(model.addSpace(name: "真机页面验收-\(UUID().uuidString.prefix(6))"))
        XCTAssertEqual(model.selectedSpaceID, testSpaceID)
        XCTAssertFalse(model.llmSettings.canRequest)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: CurrentFigmaMakeWebView().environmentObject(model))
        window.rootViewController = host
        window.makeKeyAndVisible()
        let previousIdleSetting = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        var savedImages = Set<URL>()
        var testedWebView: WKWebView?
        defer {
            model.cancelScanWork()
            CameraPreviewOverlay.shared.disarm()
            CameraEngine.shared.stop()
            testedWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "smartpaw")
            testedWebView?.navigationDelegate = nil
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
            UIApplication.shared.isIdleTimerDisabled = previousIdleSetting
            if let url = model.imageURL(for: model.selectedSpace.beforeImageName) { savedImages.insert(url) }
            for url in savedImages { try? FileManager.default.removeItem(at: url) }
        }
        func findWebView(_ view: UIView) -> WKWebView? {
            if let webView = view as? WKWebView { return webView }
            return view.subviews.lazy.compactMap { findWebView($0) }.first
        }
        let mountDeadline = Date().addingTimeInterval(20)
        while testedWebView == nil, Date() < mountDeadline {
            testedWebView = findWebView(host.view)
            if testedWebView == nil { try await Task.sleep(nanoseconds: 100_000_000) }
        }
        let webView = try XCTUnwrap(testedWebView)
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('空间地图')")
        let opened = try await webView.evaluateJavaScript("(() => { const b=Array.from(document.querySelectorAll('button')).find(b=>b.querySelector('svg.lucide-camera')); if(!b)return false;b.click();return true;})()")
        XCTAssertEqual(opened as? Bool, true)
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('多张连拍')")
        let ready = await CameraEngine.shared.waitUntilReady(timeout: 10)
        XCTAssertTrue(ready)
        for capture in 1...3 {
            let shutter = try await webView.evaluateJavaScript("(() => {const b=Array.from(document.querySelectorAll('button')).find(b=>b.style.width==='72px'&&b.style.height==='72px');if(!b)return false;b.click();return true;})()")
            XCTAssertEqual(shutter as? Bool, true)
            try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('1 / 1') && document.body.innerText.includes('重拍这张')", timeout: 25)
            let recognitionDeadline = Date().addingTimeInterval(90)
            while (model.isScanning || model.capturedImage == nil), Date() < recognitionDeadline {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertFalse(model.isScanning)
            XCTAssertNotNil(model.capturedImage)
            if let url = model.imageURL(for: model.selectedSpace.beforeImageName) { savedImages.insert(url) }
            try printVerifiedStage("SMARTPAW_HARDWARE_REACT capture=\(capture) preview=1/1 items=\(model.scannedItems.count)")
            if capture == 1 {
                try await hardwareUIClick(webView, text: "重拍这张")
                try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('重拍第 1 张')")
            } else if capture == 2 {
                try await hardwareUIClick(webView, text: "删除")
                try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('多张连拍') && !document.body.innerText.includes('重拍这张')")
            }
        }
        // Swipe the real carousel to its plus card, add a second real photo, then delete it.
        for (event, x) in [("mousedown", 300), ("mousemove", 100), ("mouseup", 100)] {
            let swiped = try await webView.evaluateJavaScript("(() => {const e=Array.from(document.querySelectorAll('div')).find(e=>e.style.top==='108px'&&e.style.overflow==='hidden');if(!e)return false;e.dispatchEvent(new MouseEvent('\(event)',{bubbles:true,clientX:\(x),clientY:300}));return true;})()")
            XCTAssertEqual(swiped as? Bool, true)
        }
        try await hardwareUIWait(webView, predicate: "Array.from(document.querySelectorAll('button')).some(b=>b.innerText.trim()==='重拍这张'&&b.disabled)")
        let added = try await webView.evaluateJavaScript("(() => {const e=Array.from(document.querySelectorAll('div')).find(e=>e.style.cursor==='pointer'&&e.innerText.trim()==='添加照片');if(!e)return false;e.click();return true;})()")
        XCTAssertEqual(added as? Bool, true)
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('多张连拍') && !document.body.innerText.includes('重拍这张')")
        let addCameraReady = await CameraEngine.shared.waitUntilReady(timeout: 10)
        XCTAssertTrue(addCameraReady)
        _ = try await webView.evaluateJavaScript("Array.from(document.querySelectorAll('button')).find(b=>b.style.width==='72px'&&b.style.height==='72px').click();true")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('2 / 2')", timeout: 25)
        try await hardwareUIClick(webView, text: "删除")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('1 / 1')")
        try printVerifiedStage("SMARTPAW_HARDWARE_REACT carouselAdd=2/2 deleteNeighbor=1/1")
        let photoSnapshot: UIImage? = await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in continuation.resume(returning: image) }
        }
        let previewAttachment = XCTAttachment(image: try XCTUnwrap(photoSnapshot))
        previewAttachment.name = "production-react-real-photo-preview"
        previewAttachment.lifetime = .keepAlways
        add(previewAttachment)
        try await hardwareUIClick(webView, text: "提交")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('确认方案，开始整理')", timeout: 120)
        try await hardwareUIClick(webView, text: "确认方案，开始整理")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('选择整理分区')")
        try await hardwareUIClick(webView, text: "开始 →")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('Step 1/')", timeout: 90)
        XCTAssertFalse(try XCTUnwrap(model.activePlan).steps.isEmpty)
        XCTAssertFalse(model.scannedItems.isEmpty, "A black/empty scene must not close the recognition-to-plan gate.")
        try printVerifiedStage("SMARTPAW_HARDWARE_REACT planSteps=\(model.activePlan?.steps.count ?? 0) reachedGuide=true")
        // Observe replies while retaining the production React request receiver.
        _ = try await webView.evaluateJavaScript("(() => { window.__hardwareResponses={}; const receive=window.__smartPawReceive; window.__smartPawReceive=(response)=>{window.__hardwareResponses[response.requestId]=response;receive?.(response);};return true;})()")
        let plan = try XCTUnwrap(model.activePlan)
        let spaceID = model.selectedSpace.id
        XCTAssertEqual(spaceID, testSpaceID)
        let completedBefore = model.selectedSpace.completedPlans.count
        _ = try await hardwareBridgeRequest(webView, command: "plan.pause.set", payload: [
            "spaceID": spaceID.uuidString, "planID": plan.id.uuidString, "isPaused": true
        ])
        let pausedDiskModel = restoredModel(selecting: testSpaceID)
        XCTAssertEqual(pausedDiskModel.activePlan?.id, plan.id)
        XCTAssertEqual(pausedDiskModel.activePlan?.isPaused, true)
        XCTAssertEqual(pausedDiskModel.activePlan?.steps.map(\.status), plan.steps.map(\.status))
        _ = try await hardwareBridgeRequest(webView, command: "plan.pause.set", payload: [
            "spaceID": spaceID.uuidString, "planID": plan.id.uuidString, "isPaused": false
        ])
        XCTAssertEqual(restoredModel(selecting: testSpaceID).activePlan?.isPaused, false)
        try printVerifiedStage("SMARTPAW_HARDWARE_REACT pauseResumeBridge=true pausedDiskRestore=true")

        // Preparation and review must not complete native placement steps.
        try await hardwareUIClick(webView, text: "下一步")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('Step 2/')")
        try await hardwareUIClick(webView, text: "复核")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('物品复核')")
        XCTAssertEqual(model.activePlan?.steps.map(\.status), plan.steps.map(\.status))
        try await hardwareUIClick(webView, text: "返回继续整理")
        try await hardwareUIClick(webView, text: "下一步")
        for (offset, _) in plan.steps.enumerated() {
            try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('Step \(offset + 3)/')")
            try await hardwareUIClick(webView, text: offset + 1 == plan.steps.count ? "完成收纳" : "下一步")
            let deadline = Date().addingTimeInterval(15)
            while model.activePlan?.steps.filter({ $0.status == .done }).count != offset + 1, Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            XCTAssertEqual(model.activePlan?.steps.filter({ $0.status == .done }).count, offset + 1)
        }
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('整理步骤已完成')")
        XCTAssertEqual(model.selectedSpace.completedPlans.count, completedBefore)
        XCTAssertNotNil(model.activePlan, "Completing steps alone must not archive the plan.")
        let awaitingPhotoDiskModel = restoredModel(selecting: testSpaceID)
        XCTAssertEqual(awaitingPhotoDiskModel.activePlan?.steps.filter({ $0.status == .done }).count, plan.steps.count)
        XCTAssertEqual(awaitingPhotoDiskModel.selectedSpace.completedPlans.count, completedBefore)
        try await hardwareUIClick(webView, text: "继续")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('整理清单')")
        try await hardwareUIClick(webView, text: "查看整理成果")
        try await hardwareUIWait(webView, predicate: "!!document.querySelector('button[aria-label=\"拍摄完成照\"]')")
        let completionCameraReady = await CameraEngine.shared.waitUntilReady(timeout: 10)
        XCTAssertTrue(completionCameraReady)
        _ = try await webView.evaluateJavaScript("document.querySelector('button[aria-label=\"拍摄完成照\"]').click();true")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('对比整理前后')", timeout: 25)
        XCTAssertEqual(model.selectedSpace.completedPlans.count, completedBefore)
        XCTAssertNotNil(model.activePlan, "A staged after-photo must not archive before confirmation.")
        XCTAssertTrue(model.selectedSpace.afterImageName.isEmpty)
        XCTAssertEqual(restoredModel(selecting: testSpaceID).selectedSpace.completedPlans.count, completedBefore)
        try await hardwareUIClick(webView, text: "查看成就")
        try await hardwareUIWait(webView, predicate: "document.body.innerText.includes('空间地图')", timeout: 25)
        XCTAssertNil(model.activePlan)
        let completedPlan = try XCTUnwrap(model.selectedSpace.completedPlans.first)
        XCTAssertEqual(completedPlan.id, plan.id)
        XCTAssertNotNil(completedPlan.completedAt)
        XCTAssertEqual(model.selectedSpace.completedPlans.count, completedBefore + 1)
        let afterURL = try XCTUnwrap(model.imageURL(for: model.selectedSpace.afterImageName))
        XCTAssertNotNil(UIImage(contentsOfFile: afterURL.path))
        savedImages.insert(afterURL)
        let finalDiskModel = restoredModel(selecting: testSpaceID)
        XCTAssertNil(finalDiskModel.activePlan)
        XCTAssertEqual(finalDiskModel.selectedSpace.completedPlans.first?.id, plan.id)
        XCTAssertEqual(finalDiskModel.selectedSpace.afterImageName, model.selectedSpace.afterImageName)
        XCTAssertTrue(finalDiskModel.selectedSpace.hasVerifiedComparison)
        XCTAssertNotNil(finalDiskModel.imageURL(for: finalDiskModel.selectedSpace.afterImageName))
        try printVerifiedStage("SMARTPAW_HARDWARE_REACT reviewDoesNotComplete=true placementSteps=\(plan.steps.count) unconfirmedPhotoNotArchived=true confirmedArchive=true jsonDiskRestore=true")

        #endif
    }

    @MainActor
    private func hardwareUIClick(_ webView: WKWebView, text: String) async throws {
        let textJSON = String(decoding: try JSONEncoder().encode(text), as: UTF8.self)
        let result = try await webView.evaluateJavaScript("(() => { const b=Array.from(document.querySelectorAll('button')).find(b=>b.innerText.trim()===\(textJSON));if(!b)return false;b.click();return true;})()")
        XCTAssertEqual(result as? Bool, true, "Missing production UI button: \(text)")
    }

    @MainActor
    private func hardwareUIWait(_ webView: WKWebView, predicate: String, timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? await webView.evaluateJavaScript(predicate)) as? Bool == true { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let page = (try? await webView.evaluateJavaScript("document.body.innerText.slice(0,2000)")) as? String ?? "unavailable"
        throw NSError(domain: "SmartPawHardwareUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out: \(predicate); page: \(page)"])
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
        assertHint(plan.steps.last?.arHint, approximatelyEquals: items[1].arHint)
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

    func testStoragePlanDecodesLegacyDataWithoutPauseState() throws {
        let plan = StoragePlan(
            style: .warmVisible,
            timeBudget: .ten,
            summary: "旧版计划",
            toolList: [],
            steps: [StorageStep(title: "第一步", detail: "处理书本", zone: "书架", status: .active, itemIDs: [])]
        )
        let encoded = try JSONEncoder().encode(plan)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "isPaused")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let restored = try JSONDecoder().decode(StoragePlan.self, from: legacyData)

        XCTAssertFalse(restored.isPaused)
        XCTAssertEqual(restored.id, plan.id)
        XCTAssertEqual(restored.steps, plan.steps)
    }

    @MainActor
    func testPlanPausePersistsAcrossViewModelRestartAndResumeKeepsProgress() throws {
        let plan = StoragePlan(
            style: .quickReset,
            timeBudget: .ten,
            summary: "跨重启测试",
            toolList: [],
            steps: [
                StorageStep(title: "已完成", detail: "处理书本", zone: "书架", status: .done, itemIDs: []),
                StorageStep(title: "当前步骤", detail: "处理文具", zone: "抽屉", status: .active, itemIDs: []),
                StorageStep(title: "下一步", detail: "整理线材", zone: "桌面", status: .pending, itemIDs: [])
            ]
        )
        var snapshot = AppStateSnapshot.initial
        snapshot.spaces[0].activePlan = plan
        let storage = FailingWriteStorageStore(snapshot: snapshot)
        let dependencies = AppDependencies(
            scanService: FailingScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: storage,
            credentialStore: InMemoryCredentialStore()
        )
        let firstLaunch = AppViewModel(dependencies: dependencies)
        let originalSteps = try XCTUnwrap(firstLaunch.activePlan?.steps)

        XCTAssertTrue(firstLaunch.setPlanPaused(spaceID: snapshot.spaces[0].id, planID: plan.id, isPaused: true))
        XCTAssertTrue(firstLaunch.activePlan?.isPaused == true)
        XCTAssertFalse(firstLaunch.completeStep(try XCTUnwrap(originalSteps.first(where: { $0.status == .active })).id))
        XCTAssertEqual(firstLaunch.activePlan?.steps, originalSteps)

        let relaunched = AppViewModel(dependencies: dependencies)
        XCTAssertTrue(relaunched.activePlan?.isPaused == true)
        XCTAssertEqual(relaunched.activePlan?.steps, originalSteps)
        XCTAssertTrue(relaunched.setPlanPaused(spaceID: snapshot.spaces[0].id, planID: plan.id, isPaused: false))
        XCTAssertFalse(relaunched.activePlan?.isPaused ?? true)
        XCTAssertEqual(relaunched.activePlan?.steps, originalSteps)
    }

    @MainActor
    func testReusingArchivedPlanCreatesIndependentExecutionAndPersistsIt() throws {
        var snapshot = AppStateSnapshot.initial
        snapshot.spaces[0].activePlan = nil
        snapshot.spaces[0].completedPlans = [DemoData.completedPlan]
        let storage = FailingWriteStorageStore(snapshot: snapshot)
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        let original = DemoData.completedPlan
        let spaceID = snapshot.spaces[0].id

        XCTAssertFalse(viewModel.reusePlan(spaceID: UUID(), planID: original.id))
        XCTAssertFalse(viewModel.reusePlan(spaceID: spaceID, planID: UUID()))
        XCTAssertTrue(viewModel.reusePlan(spaceID: spaceID, planID: original.id))
        let restarted = try XCTUnwrap(viewModel.activePlan)
        XCTAssertNotEqual(restarted.id, original.id)
        XCTAssertNil(restarted.completedAt)
        XCTAssertFalse(restarted.isPaused)
        XCTAssertEqual(restarted.steps.first?.status, .active)
        XCTAssertTrue(restarted.steps.dropFirst().allSatisfy { $0.status == .pending })
        XCTAssertEqual(restarted.steps.map(\.title), original.steps.map(\.title))
        XCTAssertTrue(Set(restarted.steps.map(\.id)).isDisjoint(with: original.steps.map(\.id)))
        XCTAssertEqual(viewModel.selectedSpace.completedPlans, [original])
        XCTAssertEqual(AppViewModel(dependencies: dependencies).activePlan, restarted)
    }

    @MainActor
    func testReusingPlanWriteFailureRestoresSpaceAndExecutionZones() throws {
        var snapshot = AppStateSnapshot.initial
        snapshot.spaces[0].activePlan = nil
        snapshot.spaces[0].completedPlans = [DemoData.completedPlan]
        let storage = FailingWriteStorageStore(snapshot: snapshot)
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        let previousSpace = viewModel.selectedSpace
        let previousZones = viewModel.selectedExecutionZones
        storage.failsWrites = true

        XCTAssertFalse(viewModel.reusePlan(spaceID: previousSpace.id, planID: DemoData.completedPlan.id))
        XCTAssertEqual(viewModel.selectedSpace, previousSpace)
        XCTAssertEqual(viewModel.selectedExecutionZones, previousZones)
        XCTAssertEqual(try storage.loadState()?.spaces[0], previousSpace)
    }

    @MainActor
    func testPlanPauseRejectsStaleIdentifiersAndCompletedPlans() throws {
        let plan = StoragePlan(
            style: .quickReset,
            timeBudget: .ten,
            summary: "有效计划",
            toolList: [],
            steps: [StorageStep(title: "当前步骤", detail: "处理书本", zone: "书架", status: .active, itemIDs: [])]
        )
        var snapshot = AppStateSnapshot.initial
        snapshot.spaces[0].activePlan = plan
        let storage = FailingWriteStorageStore(snapshot: snapshot)
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)

        XCTAssertFalse(viewModel.setPlanPaused(spaceID: UUID(), planID: plan.id, isPaused: true))
        XCTAssertFalse(viewModel.setPlanPaused(spaceID: snapshot.spaces[0].id, planID: UUID(), isPaused: true))
        XCTAssertFalse(viewModel.activePlan?.isPaused ?? true)

        var completedSnapshot = AppStateSnapshot.initial
        completedSnapshot.spaces[0].activePlan = DemoData.completedPlan
        let completedDependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: FailingWriteStorageStore(snapshot: completedSnapshot), credentialStore: InMemoryCredentialStore())
        let completedViewModel = AppViewModel(dependencies: completedDependencies)
        XCTAssertFalse(completedViewModel.setPlanPaused(spaceID: completedSnapshot.spaces[0].id, planID: DemoData.completedPlan.id, isPaused: true))
    }

    @MainActor
    func testPlanPauseWriteFailureRollsBackMemoryAndPersistedState() throws {
        let plan = StoragePlan(
            style: .quickReset,
            timeBudget: .ten,
            summary: "写入回滚测试",
            toolList: [],
            steps: [StorageStep(title: "当前步骤", detail: "处理书本", zone: "书架", status: .active, itemIDs: [])]
        )
        var snapshot = AppStateSnapshot.initial
        snapshot.spaces[0].activePlan = plan
        let storage = FailingWriteStorageStore(snapshot: snapshot)
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        storage.failsWrites = true

        XCTAssertFalse(viewModel.setPlanPaused(spaceID: snapshot.spaces[0].id, planID: plan.id, isPaused: true))

        XCTAssertFalse(viewModel.activePlan?.isPaused ?? true)
        XCTAssertEqual(try storage.loadState()?.spaces[0].activePlan, plan)
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
        XCTAssertEqual(viewModel.selectedSpace.name, "我的空间")
        XCTAssertTrue(viewModel.catalogItems.isEmpty)
    }

    func testLLMSettingsRejectUnsafeOrIncompleteEndpoints() {
        XCTAssertFalse(LLMSettings(isEnabled: true, endpoint: "http://example.com/v1/responses", apiKey: "test-key", model: "model", hasCloudConsent: true).canRequest)
        XCTAssertFalse(LLMSettings(isEnabled: true, endpoint: "https://", apiKey: "test-key", model: "model", hasCloudConsent: true).canRequest)
        XCTAssertTrue(LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "model", hasCloudConsent: true).canRequest)
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
    func testPhotoScanSessionReturnsPerImageResultsAndClearsOnlyTransientItems() async {
        let viewModel = AppViewModel(dependencies: .outOfOrderScan)
        let firstImage = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in }
        let secondImage = UIGraphicsImageRenderer(size: CGSize(width: 25, height: 25)).image { _ in }

        let first = await viewModel.scanImages([firstImage], accumulate: true)
        let second = await viewModel.scanImages([secondImage], accumulate: true)

        XCTAssertEqual(first.map(\.name), ["first"])
        XCTAssertEqual(second.map(\.name), ["second"])
        XCTAssertEqual(Set(viewModel.scannedItems.map(\.name)), Set(["first", "second"]))

        viewModel.beginPhotoScanSession()

        XCTAssertTrue(viewModel.scannedItems.isEmpty)
        XCTAssertEqual(Set(viewModel.selectedSpace.detectedItems.map(\.name)), Set(["first", "second"]))
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

    func testManuallyEnteredItemsHaveTextInstructionsWithoutInventedARLocations() {
        let item = DetectedItem(name: "课本", category: .books, confidence: 1)
        let plan = RuleBasedPlanningService().makePlan(for: AppStateSnapshot.initial.spaces[0], selectedItems: [item], style: .quickReset, timeBudget: .ten)
        XCTAssertEqual(plan.steps.count, 1)
        XCTAssertEqual(plan.steps.first?.itemIDs, [item.id])
        XCTAssertNil(plan.steps.first?.arHint)
        XCTAssertNil(plan.steps.first?.arMask)
    }

    @MainActor
    func testCompletionSaveFailureKeepsActivePlanAndAvoidsFalseAchievement() throws {
        let storage = FailingWriteStorageStore()
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.makePlanFromScan()
        let plan = try XCTUnwrap(viewModel.activePlan)
        plan.steps.forEach { viewModel.completeStep($0.id) }
        let previousSpace = viewModel.selectedSpace
        let previousAchievements = viewModel.achievements
        storage.failsWrites = true
        XCTAssertFalse(viewModel.finishActivePlan(afterImage: .smartPawTestImage()))
        XCTAssertEqual(viewModel.selectedSpace, previousSpace)
        XCTAssertEqual(viewModel.achievements, previousAchievements)
        XCTAssertNil(viewModel.latestUnlockedAchievement)
        XCTAssertTrue(viewModel.message?.contains("保存失败") == true)
    }

    @MainActor
    func testAISettingsWriteFailureRestoresMemoryAndKeychainState() {
        let storage = FailingWriteStorageStore()
        let credentials = InMemoryCredentialStore(apiKey: "old-key")
        let dependencies = AppDependencies(
            scanService: EmptyScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: storage,
            credentialStore: credentials
        )
        let viewModel = AppViewModel(dependencies: dependencies)
        let previousSettings = viewModel.llmSettings
        let nextSettings = LLMSettings(isEnabled: false, endpoint: previousSettings.endpoint, apiKey: "new-key", model: previousSettings.model)

        storage.failsWrites = true
        XCTAssertFalse(viewModel.saveLLMSettings(nextSettings))
        XCTAssertEqual(viewModel.llmSettings, previousSettings)
        XCTAssertEqual(credentials.loadAPIKey(), "old-key")
    }

    @MainActor
    func testFailedWritesKeepManualItemsAndStepProgressRetryable() async throws {
        let storage = FailingWriteStorageStore()
        let cloud = CountingCloudPlanningService()
        let dependencies = AppDependencies(scanService: EmptyScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: cloud, storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        XCTAssertTrue(viewModel.replaceScannedItems([DetectedItem(name: "电脑", category: .electronics, confidence: 1)]))
        XCTAssertTrue(viewModel.addManualItem(name: "已保存课本", category: .books, forScan: true))
        XCTAssertTrue(viewModel.makePlanFromScan())
        XCTAssertTrue(viewModel.saveLLMSettings(LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "test-model", hasCloudConsent: true)))
        let savedSpace = viewModel.selectedSpace
        let savedScan = viewModel.scannedItems
        let activeStep = try XCTUnwrap(viewModel.activePlan?.steps.first(where: { $0.status == .active }))
        viewModel.selectedTab = .capture
        viewModel.selectedExecutionZones = [activeStep.zone]
        let savedZones = viewModel.selectedExecutionZones

        storage.failsWrites = true
        XCTAssertFalse(viewModel.completeStep(activeStep.id))
        XCTAssertFalse(viewModel.addManualItem(name: "待重试笔记", category: .books, forScan: true))
        XCTAssertFalse(viewModel.replaceScannedItems([]))
        XCTAssertFalse(viewModel.makePlanFromScan())
        let cloudPlanSaved = await viewModel.makePlanFromScanUsingCloudIfAvailable()
        XCTAssertFalse(cloudPlanSaved)
        let requests = await cloud.requestCount
        XCTAssertEqual(requests, 0, "A plan that could not be saved locally must not be sent to the cloud.")
        XCTAssertEqual(viewModel.selectedSpace, savedSpace)
        XCTAssertEqual(viewModel.scannedItems, savedScan)
        XCTAssertEqual(viewModel.selectedExecutionZones, savedZones)
        XCTAssertEqual(viewModel.selectedTab, .capture)
        XCTAssertTrue(viewModel.message?.contains("保存失败") == true)
        XCTAssertEqual(AppViewModel(dependencies: dependencies).selectedSpace, savedSpace)

        storage.failsWrites = false
        XCTAssertTrue(viewModel.completeStep(activeStep.id))
        XCTAssertTrue(viewModel.addManualItem(name: "待重试笔记", category: .books, forScan: true))
        let relaunched = AppViewModel(dependencies: dependencies)
        XCTAssertEqual(relaunched.activePlan?.steps.first(where: { $0.id == activeStep.id })?.status, .done)
        XCTAssertEqual(relaunched.catalogItems.filter { $0.name == "待重试笔记" }.count, 1)
        XCTAssertTrue(relaunched.catalogItems.contains { $0.name == "已保存课本" })

        let deferredCloud = DeferredCloudPlanningService()
        let cloudDependencies = AppDependencies(scanService: EmptyScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: deferredCloud, storageStore: storage, credentialStore: dependencies.credentialStore)
        let cloudViewModel = AppViewModel(dependencies: cloudDependencies)
        let planning = Task { await cloudViewModel.makePlanFromScanUsingCloudIfAvailable() }
        await deferredCloud.waitForRequest()
        let savedLocalPlan = try XCTUnwrap(cloudViewModel.activePlan)
        let localZones = cloudViewModel.selectedExecutionZones
        storage.failsWrites = true
        await deferredCloud.complete()
        let refinedPlanSaved = await planning.value
        XCTAssertFalse(refinedPlanSaved)
        XCTAssertEqual(cloudViewModel.activePlan, savedLocalPlan)
        XCTAssertEqual(cloudViewModel.selectedExecutionZones, localZones)
        XCTAssertEqual(AppViewModel(dependencies: cloudDependencies).activePlan, savedLocalPlan)
        XCTAssertTrue(cloudViewModel.message?.contains("保存失败") == true)
    }

    @MainActor
    func testFailedWritesRollbackSpaceCatalogCommunityAndScheduleMutations() async throws {
        let storage = FailingWriteStorageStore()
        try storage.saveState(DemoData.snapshot)
        let dependencies = AppDependencies(
            scanService: EmptyScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: storage,
            credentialStore: InMemoryCredentialStore()
        )
        let viewModel = AppViewModel(dependencies: dependencies)
        let originalSpaces = viewModel.spaces
        let originalSelectedSpaceID = viewModel.selectedSpaceID
        let originalItems = viewModel.catalogItems
        let originalCases = viewModel.communityCases
        let originalLikes = viewModel.likedCommunityCaseIDs
        let originalFavorites = viewModel.favoriteCommunityCaseIDs
        let originalSchedules = viewModel.scheduleItems

        storage.failsWrites = true
        let scanResult = await viewModel.scanImages([.smartPawTestImage()])
        XCTAssertTrue(scanResult.isEmpty)
        XCTAssertFalse(viewModel.lastScanPersisted)
        XCTAssertEqual(viewModel.spaces, originalSpaces)
        XCTAssertEqual(viewModel.catalogItems, originalItems)

        XCTAssertNil(viewModel.addSpace(name: "不应出现的空间"))
        XCTAssertEqual(viewModel.spaces, originalSpaces)
        XCTAssertEqual(viewModel.selectedSpaceID, originalSelectedSpaceID)

        XCTAssertFalse(viewModel.renameSpace(viewModel.spaces[0].id, name: "不应保存的重命名"))
        XCTAssertEqual(viewModel.spaces, originalSpaces)
        XCTAssertFalse(viewModel.deleteSpace(viewModel.spaces[0].id))
        XCTAssertEqual(viewModel.spaces, originalSpaces)

        let item = try XCTUnwrap(originalItems.first)
        XCTAssertFalse(viewModel.removeCatalogItem(item.id))
        XCTAssertEqual(viewModel.catalogItems, originalItems)
        var editedItem = item
        editedItem.name = "不应保存的修改"
        XCTAssertFalse(viewModel.updateCatalogItem(editedItem))
        XCTAssertEqual(viewModel.catalogItems, originalItems)

        let communityCase = try XCTUnwrap(originalCases.first)
        XCTAssertFalse(viewModel.toggleCommunityLike(communityCase.id))
        XCTAssertEqual(viewModel.communityCases, originalCases)
        XCTAssertEqual(viewModel.likedCommunityCaseIDs, originalLikes)
        XCTAssertFalse(viewModel.toggleCommunityFavorite(communityCase.id))
        XCTAssertEqual(viewModel.favoriteCommunityCaseIDs, originalFavorites)
        XCTAssertFalse(viewModel.addCommunityComment(to: communityCase.id, body: "不应发布"))
        XCTAssertTrue(viewModel.comments(for: communityCase.id).isEmpty)

        let schedule = try XCTUnwrap(originalSchedules.first)
        XCTAssertFalse(viewModel.toggleScheduleItem(schedule.id))
        XCTAssertEqual(viewModel.scheduleItems, originalSchedules)
        XCTAssertFalse(viewModel.addScheduleItem(title: "不应创建", dueDate: Date(), note: ""))
        XCTAssertEqual(viewModel.scheduleItems, originalSchedules)
        XCTAssertFalse(viewModel.deleteScheduleItem(schedule.id))
        XCTAssertEqual(viewModel.scheduleItems, originalSchedules)
    }

    @MainActor
    func testManualPlanCanCompleteWithoutClaimingANonexistentBeforePhoto() throws {
        let viewModel = AppViewModel(dependencies: .failingScan)
        viewModel.addManualItem(name: "书本", category: .books)
        viewModel.makePlanFromScan()
        let plan = try XCTUnwrap(viewModel.activePlan)
        plan.steps.forEach { viewModel.completeStep($0.id) }
        viewModel.finishActivePlan(afterImage: .smartPawTestImage())
        XCTAssertEqual(viewModel.completedCount, 1)
        XCTAssertFalse(viewModel.selectedSpace.hasVerifiedComparison)
        viewModel.shareLatestCompletion()
        XCTAssertTrue(viewModel.communityCases.isEmpty)
    }

    @MainActor
    func testRecoveryModePreservesUnreadableStorageUntilExplicitReset() {
        let storage = UnreadableStorageStore()
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        viewModel.addManualItem(name: "待恢复记录", category: .books)
        XCTAssertEqual(storage.saveCount, 0)
        XCTAssertTrue(viewModel.message?.contains("恢复模式") == true)
    }

    @MainActor
    func testNewInstallationStartsWithRealEmptyDataAndCloudDisabled() {
        let viewModel = AppViewModel(dependencies: .failingScan)
        XCTAssertEqual(viewModel.spaces.count, 1)
        XCTAssertTrue(viewModel.catalogItems.isEmpty)
        XCTAssertTrue(viewModel.completedPlans.isEmpty)
        XCTAssertTrue(viewModel.communityCases.isEmpty)
        XCTAssertTrue(viewModel.scheduleItems.isEmpty)
        XCTAssertFalse(viewModel.llmSettings.isEnabled)
        XCTAssertFalse(viewModel.llmSettings.hasCloudConsent)
        XCTAssertFalse(viewModel.llmSettings.canRequestVision)
    }

    func testCloudConsentIsRequiredForBothTextAndPhotoRequests() throws {
        var settings = LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "test-model")
        XCTAssertFalse(settings.canRequest)
        XCTAssertFalse(settings.canRequestVision)
        settings.hasCloudConsent = true
        XCTAssertTrue(settings.canRequest)
        XCTAssertTrue(settings.canRequestVision)
        settings.visionEndpoint = "http://example.com/vision"
        XCTAssertFalse(settings.canRequestVision)
        settings.endpoint = "http://localhost:8080/v1/responses"
        XCTAssertFalse(settings.canRequest)

        let legacyJSON = Data(#"{"isEnabled":true,"endpoint":"https://example.com/v1/responses","model":"test-model"}"#.utf8)
        let legacy = try JSONDecoder().decode(LLMSettings.self, from: legacyJSON)
        XCTAssertFalse(legacy.hasCloudConsent)
    }

    @MainActor
    func testSavingAISettingsPreservesVisionConfigurationAndRejectsMissingConsent() {
        let viewModel = AppViewModel(dependencies: .failingScan)
        var settings = LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "test-model", visionEndpoint: "https://example.com/vision", visionModel: "vision-model")
        XCTAssertFalse(viewModel.saveLLMSettings(settings))
        XCTAssertFalse(viewModel.llmSettings.isEnabled)
        settings.hasCloudConsent = true
        XCTAssertTrue(viewModel.saveLLMSettings(settings))
        XCTAssertEqual(viewModel.llmSettings.visionEndpoint, "https://example.com/vision")
        XCTAssertEqual(viewModel.llmSettings.visionModel, "vision-model")
        XCTAssertTrue(viewModel.llmSettings.hasCloudConsent)
    }

    @MainActor
    func testDeletingEveryScheduleDoesNotRecreateDemoRemindersAfterRelaunch() {
        let dependencies = AppDependencies.test
        let viewModel = AppViewModel(dependencies: dependencies)
        viewModel.scheduleItems.map(\.id).forEach { viewModel.deleteScheduleItem($0) }
        XCTAssertTrue(AppViewModel(dependencies: dependencies).scheduleItems.isEmpty)
    }

    func testResetReplacesBackupSoDeletedDataCannotReturnDuringRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appendingPathComponent("state.json")
        let store = JSONStorageStore(stateURL: stateURL, credentialStore: InMemoryCredentialStore())
        try store.saveState(DemoData.snapshot)
        try store.saveState(DemoData.snapshot)
        try store.resetState(.initial)
        try FileManager.default.removeItem(at: stateURL)
        let restored = try XCTUnwrap(store.loadState())
        XCTAssertTrue(restored.spaces.flatMap(\.detectedItems).isEmpty)
        XCTAssertTrue(restored.communityCases.isEmpty)
        XCTAssertTrue(restored.scheduleItems.isEmpty)
    }

    func testVisionFallbackDoesNotPresentSceneLabelsAsPossessions() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
        }
        let items = try await VisionScanService().scanImage(image)
        let sceneLabels: Set<String> = ["outdoor", "indoor", "room", "interior", "unknown"]
        XCTAssertFalse(items.contains { sceneLabels.contains($0.name.lowercased()) }, "Global scene classifications cannot be stored as possessions.")
    }

    @MainActor
    func testUnrecognizedPhotoSupportsManualEntryAndACompleteLocalPlan() async throws {
        let dependencies = AppDependencies(scanService: EmptyScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: InMemoryStorageStore(), credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        await viewModel.scanImages([.smartPawTestImage()])
        XCTAssertTrue(viewModel.scannedItems.isEmpty)
        XCTAssertFalse(viewModel.isScanning)
        viewModel.addManualItem(name: "待整理课本", category: .books, forScan: true)
        viewModel.makePlanFromScan()
        let plan = try XCTUnwrap(viewModel.activePlan)
        XCTAssertFalse(plan.steps.isEmpty)
        XCTAssertNil(plan.steps.first?.arHint)
        plan.steps.forEach { viewModel.completeStep($0.id) }
        XCTAssertTrue(viewModel.finishActivePlan(afterImage: .smartPawTestImage()))
        let relaunched = AppViewModel(dependencies: dependencies)
        XCTAssertEqual(relaunched.completedCount, 1)
        XCTAssertEqual(relaunched.catalogItems.first?.name, "待整理课本")
        XCTAssertFalse(relaunched.llmSettings.canRequest)
    }

    @MainActor
    func testCancelledPhotoWorkCannotWriteLateRecognitionResults() async {
        for usesBatch in [false, true] {
            for cancelsTask in [false, true] {
                let scanner = DeferredScanService()
                let storage = InMemoryStorageStore()
                try? storage.saveState(.initial)
                let dependencies = AppDependencies(scanService: scanner, planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: storage, credentialStore: InMemoryCredentialStore())
                let viewModel = AppViewModel(dependencies: dependencies)
                let originalSpace = viewModel.selectedSpace
                let scan = Task {
                    if usesBatch {
                        await viewModel.scanImages([.smartPawTestImage()])
                    } else {
                        await viewModel.scanImage(.smartPawTestImage())
                    }
                }
                await scanner.waitForRequest()
                if cancelsTask {
                    scan.cancel()
                } else {
                    viewModel.cancelScanWork()
                }
                await scanner.complete()
                await scan.value
                XCTAssertEqual(viewModel.selectedSpace, originalSpace)
                XCTAssertTrue(viewModel.scannedItems.isEmpty)
                XCTAssertFalse(viewModel.isScanning)
                XCTAssertEqual(AppViewModel(dependencies: dependencies).selectedSpace, originalSpace)
            }
        }
    }

    @MainActor
    func testCancellingAfterCompletedPhotoRestoresPreScanSpaceAndPersistsIt() async throws {
        let storage = seededStorageStore()
        let dependencies = AppDependencies(
            scanService: SingleItemScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: storage,
            credentialStore: InMemoryCredentialStore()
        )
        let viewModel = AppViewModel(dependencies: dependencies)
        let originalSpace = viewModel.selectedSpace
        let originalScannedItems = viewModel.scannedItems

        viewModel.beginPhotoScanSession()
        let results = await viewModel.scanImages([.smartPawTestImage()])
        XCTAssertEqual(results.map(\.name), ["扫描中的新物品"])
        XCTAssertNotEqual(viewModel.selectedSpace, originalSpace)

        viewModel.cancelScanWork()

        XCTAssertEqual(viewModel.selectedSpace, originalSpace)
        XCTAssertEqual(viewModel.scannedItems, originalScannedItems)
        let relaunched = AppViewModel(dependencies: dependencies)
        XCTAssertEqual(relaunched.selectedSpace, originalSpace)
    }

    @MainActor
    func testLatePhotoResultsCannotWriteIntoAnotherSpace() async {
        let scanner = DeferredScanService()
        let dependencies = AppDependencies(scanService: scanner, planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: seededStorageStore(), credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        let secondSpace = viewModel.spaces[1]
        let scan = Task { await viewModel.scanImages([.smartPawTestImage()]) }
        await scanner.waitForRequest()
        viewModel.selectSpace(secondSpace.id)
        await scanner.complete()
        _ = await scan.value
        XCTAssertTrue(viewModel.scannedItems.isEmpty)
        XCTAssertEqual(viewModel.selectedSpace.detectedItems, secondSpace.detectedItems)
        XCTAssertEqual(viewModel.selectedSpace.beforeImageName, secondSpace.beforeImageName)
    }

    @MainActor
    func testResetDiscardsInFlightRecognitionAndCredentials() async throws {
        let defaultsName = "SmartPawTests.Reset.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        let documents = FileManager.default.temporaryDirectory
            .appendingPathComponent(defaultsName, isDirectory: true)
        let imageDirectory = documents.appendingPathComponent("SmartPawImages", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        try Data("isolated photo".utf8).write(to: imageDirectory.appendingPathComponent("before-reset.jpg"))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: documents)
        }
        let scanner = DeferredScanService()
        let credentials = InMemoryCredentialStore(apiKey: "test-key")
        let dependencies = AppDependencies(scanService: scanner, planningService: RuleBasedPlanningService(), cloudPlanningService: PassthroughCloudPlanningService(), storageStore: seededStorageStore(), credentialStore: credentials)
        var imageGenerationResetCount = 0
        let viewModel = AppViewModel(
            dependencies: dependencies,
            defaults: defaults,
            documentsDirectory: documents,
            imageGenerationReset: {
                imageGenerationResetCount += 1
                return true
            }
        )
        defaults.set([UUID().uuidString], forKey: "SmartPaw.community.likedCaseIDs")
        let scan = Task { await viewModel.scanImages([.smartPawTestImage()]) }
        await scanner.waitForRequest()
        XCTAssertTrue(viewModel.resetLocalData(), viewModel.message ?? "重置失败")
        await scanner.complete()
        _ = await scan.value
        XCTAssertEqual(imageGenerationResetCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: imageDirectory.path))
        XCTAssertNil(defaults.object(forKey: "SmartPaw.community.likedCaseIDs"))
        XCTAssertTrue(viewModel.catalogItems.isEmpty)
        XCTAssertTrue(viewModel.scannedItems.isEmpty)
        XCTAssertTrue(viewModel.scheduleItems.isEmpty)
        XCTAssertTrue(viewModel.communityCases.isEmpty)
        XCTAssertNil(credentials.loadAPIKey())
        XCTAssertFalse(viewModel.llmSettings.canRequestVision)
    }

    @MainActor
    func testLateCloudRefinementCannotUndoCompletedStep() async throws {
        let cloud = DeferredCloudPlanningService()
        let dependencies = AppDependencies(scanService: FailingScanService(), planningService: RuleBasedPlanningService(), cloudPlanningService: cloud, storageStore: InMemoryStorageStore(), credentialStore: InMemoryCredentialStore())
        let viewModel = AppViewModel(dependencies: dependencies)
        viewModel.scannedItems = DemoData.detectedItems
        XCTAssertTrue(viewModel.saveLLMSettings(LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-key", model: "test-model", hasCloudConsent: true)))
        let planning = Task { await viewModel.makePlanFromScanUsingCloudIfAvailable() }
        await cloud.waitForRequest()
        let step = try XCTUnwrap(viewModel.activePlan?.steps.first)
        viewModel.completeStep(step.id)
        await cloud.complete()
        await planning.value
        XCTAssertEqual(viewModel.activePlan?.steps.first?.status, .done)
        XCTAssertNotEqual(viewModel.activePlan?.summary, "late cloud result")
    }

    @MainActor
    func testCloudPlanningCanRefineGeneratedPlan() async {
        let viewModel = AppViewModel(dependencies: .cloudRefining)
        viewModel.scannedItems = DemoData.detectedItems
        viewModel.updateLLMSettings(LLMSettings(
            isEnabled: true,
            endpoint: "https://example.com/v1/responses",
            apiKey: "test-key",
            model: "test-model",
            hasCloudConsent: true
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
            model: "test-model",
            hasCloudConsent: true
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

/// 社区互动状态已统一存进快照，这里额外清掉 UserDefaults 里的历史键，保证测试之间互不污染。
private let legacyCommunityReactionKeys = [
    "SmartPaw.community.likedCaseIDs",
    "SmartPaw.community.favoriteCaseIDs",
    "SmartPaw.community.followedAuthors"
]

private extension AppDependencies {
    static var test: AppDependencies {
        for key in legacyCommunityReactionKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return AppDependencies(
            scanService: YOLOSegmentationScanService(),
            planningService: RuleBasedPlanningService(),
            cloudPlanningService: PassthroughCloudPlanningService(),
            storageStore: seededStorageStore(),
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

private func seededStorageStore() -> InMemoryStorageStore {
    let store = InMemoryStorageStore()
    try? store.saveState(DemoData.snapshot)
    return store
}

private final class FailingWriteStorageStore: StorageStore {
    var failsWrites = false
    private var snapshot: AppStateSnapshot?
    init(snapshot: AppStateSnapshot? = nil) { self.snapshot = snapshot }
    func loadState() throws -> AppStateSnapshot? { snapshot }
    func saveState(_ snapshot: AppStateSnapshot) throws {
        if failsWrites { throw CocoaError(.fileWriteOutOfSpace) }
        self.snapshot = snapshot
    }
}

private final class UnreadableStorageStore: StorageStore {
    var saveCount = 0
    func loadState() throws -> AppStateSnapshot? { throw CocoaError(.fileReadCorruptFile) }
    func saveState(_ snapshot: AppStateSnapshot) throws { saveCount += 1 }
}

private actor DeferredScanService: ScanService {
    private var continuation: CheckedContinuation<[DetectedItem], Never>?
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        await withCheckedContinuation { continuation = $0 }
    }
    func waitForRequest() async {
        while continuation == nil { await Task.yield() }
    }
    func complete() {
        continuation?.resume(returning: [DetectedItem(name: "late result", category: .tools, confidence: 1)])
        continuation = nil
    }
}

private actor DeferredCloudPlanningService: CloudPlanningService {
    private var continuation: CheckedContinuation<StoragePlan, Never>?
    private var plan: StoragePlan?
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        self.plan = plan
        return await withCheckedContinuation { continuation = $0 }
    }
    func waitForRequest() async {
        while continuation == nil { await Task.yield() }
    }
    func complete() {
        guard var plan else { return }
        plan.summary = "late cloud result"
        continuation?.resume(returning: plan)
        continuation = nil
    }
}

private actor CountingCloudPlanningService: CloudPlanningService {
    private(set) var requestCount = 0
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
        requestCount += 1
        return plan
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

private struct EmptyScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] { [] }
}

private struct SingleItemScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
        [DetectedItem(name: "扫描中的新物品", category: .tools, confidence: 1)]
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
