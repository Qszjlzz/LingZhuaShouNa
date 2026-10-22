import CryptoKit
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import SmartPaw

final class PhotoImageProcessingTests: XCTestCase {
    /// Reuses one completed provider response; this test never requests image generation.
    func testRealGeneratedPreviewCacheRestoresAfterManagerRecreation() throws {
        guard let path = ProcessInfo.processInfo.environment["SMARTPAW_GENERATED_IMAGE_PATH"], !path.isEmpty else {
            throw XCTSkip("Opt in with the existing real provider output path; no network request is made.")
        }
        let generatedURL = URL(fileURLWithPath: path)
        let sourceURL = generatedURL.deletingLastPathComponent().appendingPathComponent("input-desk-2048.jpg")
        let generatedData = try Data(contentsOf: generatedURL)
        let sourceData = try Data(contentsOf: sourceURL)
        let generatedDigest = SHA256.hash(data: generatedData).map { String(format: "%02x", $0) }.joined()
        let sourceDigest = SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(generatedDigest, "28653353145ceec354420008e731ea789ccbffffacb46fbe4f4134da89334aec",
                       "Use the already recorded real provider output, rather than a substitute image.")
        XCTAssertEqual(sourceDigest, "e0d13ed7bbd68f215930ed139df2745e73970d1c21b81f47e444a0af2590ee5f")
        let generatedImage = try XCTUnwrap(UIImage(data: generatedData))
        let generatedPixels = try XCTUnwrap(generatedImage.cgImage)
        XCTAssertEqual(generatedPixels.width, 1254)
        XCTAssertEqual(generatedPixels.height, 1254)

        let suite = "SmartPaw.real-generated-cache-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suite)
        }
        let cacheID = "real-provider-space-plan"
        let prompt = "local cache verification of the recorded real provider response"
        let cacheKey = ImageGenerationManager.fingerprintedCacheID(cacheID, imageData: sourceData, prompt: prompt)
        let saved: URL = try {
            let manager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
            return try manager.persistGeneratedImage(generatedData, cacheID: cacheKey)
        }()
        let persistedData = try Data(contentsOf: saved)
        XCTAssertTrue(persistedData.starts(with: [0xff, 0xd8]), "Production persistence normalizes the response to JPEG.")
        let persistedImage = try XCTUnwrap(UIImage(data: persistedData))
        XCTAssertEqual(persistedImage.cgImage?.width, generatedPixels.width)
        XCTAssertEqual(persistedImage.cgImage?.height, generatedPixels.height)

        let recreatedManager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
        let restored = try XCTUnwrap(recreatedManager.cachedPreview(cacheID: cacheID, imageData: sourceData, prompt: prompt))
        XCTAssertEqual(restored.path, saved.path)
        XCTAssertNotNil(UIImage(contentsOfFile: restored.path))
        XCTAssertNil(recreatedManager.cachedPreview(cacheID: cacheID, imageData: sourceData, prompt: prompt + " changed"))
        XCTAssertNil(recreatedManager.cachedPreview(cacheID: cacheID, imageData: generatedData, prompt: prompt))
        XCTAssertNil(recreatedManager.cachedPreview(cacheID: "another-space-plan", imageData: sourceData, prompt: prompt))
        let attachment = XCTAttachment(image: persistedImage)
        attachment.name = "real-provider-output-restored-from-production-cache"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("SMARTPAW_REAL_GENERATED_CACHE providerSHA256=\(generatedDigest) sourceSHA256=\(sourceDigest) savedBytes=\(persistedData.count) pixels=\(generatedPixels.width)x\(generatedPixels.height) managerRecreated=true restored=true networkRequests=0")
    }

    @MainActor
    func testJSONReconstructionSelectsPersistedSpaceAndPreservesCompletion() throws {
        struct UnusedScanService: ScanService {
            func scanImage(_ image: UIImage) async throws -> [DetectedItem] {
                throw NSError(domain: "SmartPawDiskFixture", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "This storage fixture must never invoke recognition."
                ])
            }
        }
        struct IsolatedCredentialStore: CredentialStore {
            func loadAPIKey() -> String? { nil }
            func saveAPIKey(_ key: String) -> Bool { false }
            func deleteAPIKey() -> Bool { true }
        }
        struct UnusedCloudPlanningService: CloudPlanningService {
            func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan {
                throw NSError(domain: "SmartPawDiskFixture", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "This storage fixture must never invoke cloud planning."
                ])
            }
        }
        let suite = "SmartPaw.json-space-restore-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let documents = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        let images = documents.appendingPathComponent("SmartPawImages", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: documents)
        }
        let fixture = UIImage(cgImage: try makeQuadrantImage(width: 64, height: 48))
        try XCTUnwrap(fixture.jpegData(compressionQuality: 0.8))
            .write(to: images.appendingPathComponent("before-fixture.jpg"), options: .atomic)
        let plan = StoragePlan(style: .quickReset, timeBudget: .ten, summary: "Disk fixture only", toolList: [], steps: [
            StorageStep(title: "First", detail: "Fixture", zone: "Desk", status: .active, itemIDs: []),
            StorageStep(title: "Second", detail: "Fixture", zone: "Desk", status: .pending, itemIDs: [])
        ])
        var snapshot = AppStateSnapshot.initial
        let firstSpaceID = try XCTUnwrap(snapshot.spaces.first?.id)
        let target = StorageSpace(name: "Second persisted space", subtitle: "Fixture only",
                                  beforeImageName: "before-fixture.jpg", afterImageName: "",
                                  detectedItems: [], activePlan: plan)
        snapshot.spaces.append(target)
        let stateURL = documents.appendingPathComponent("fixture-state.json")
        let credentials = IsolatedCredentialStore()
        let store = JSONStorageStore(stateURL: stateURL, credentialStore: credentials)
        try store.saveState(snapshot)
        func makeModel(selectTarget: Bool = true) -> AppViewModel {
            let model = AppViewModel(dependencies: AppDependencies(
                scanService: UnusedScanService(), planningService: RuleBasedPlanningService(),
                cloudPlanningService: UnusedCloudPlanningService(),
                storageStore: JSONStorageStore(stateURL: stateURL, credentialStore: credentials),
                credentialStore: credentials), defaults: defaults, documentsDirectory: documents)
            if selectTarget { model.selectSpace(target.id) }
            return model
        }
        let defaultSelection = makeModel(selectTarget: false)
        XCTAssertEqual(defaultSelection.selectedSpaceID, firstSpaceID)
        XCTAssertNil(defaultSelection.activePlan, "Default selection is the first space, not the target with the plan.")
        XCTAssertEqual(defaultSelection.spaces.first(where: { $0.id == target.id })?.activePlan?.id, plan.id)
        let model = makeModel()
        XCTAssertEqual(model.selectedSpaceID, target.id)
        XCTAssertEqual(model.activePlan?.id, plan.id)
        XCTAssertTrue(model.setPlanPaused(spaceID: target.id, planID: plan.id, isPaused: true))
        let paused = makeModel()
        XCTAssertEqual(paused.activePlan?.isPaused, true)
        XCTAssertEqual(paused.activePlan?.steps.map(\.status), plan.steps.map(\.status))
        XCTAssertTrue(model.setPlanPaused(spaceID: target.id, planID: plan.id, isPaused: false))
        XCTAssertEqual(makeModel().activePlan?.isPaused, false)
        for step in plan.steps { XCTAssertTrue(model.completeStep(step.id)) }
        let awaitingPhoto = makeModel()
        XCTAssertEqual(awaitingPhoto.activePlan?.steps.map(\.status), [.done, .done])
        XCTAssertEqual(awaitingPhoto.selectedSpace.completedPlans.count, 0)
        XCTAssertTrue(awaitingPhoto.selectedSpace.afterImageName.isEmpty)
        XCTAssertTrue(model.finishActivePlan(afterImage: fixture))
        let afterName = model.selectedSpace.afterImageName
        XCTAssertFalse(afterName.isEmpty)
        let final = makeModel()
        XCTAssertEqual(final.selectedSpaceID, target.id)
        XCTAssertNil(final.activePlan)
        XCTAssertEqual(final.selectedSpace.completedPlans.first?.id, plan.id)
        XCTAssertEqual(final.selectedSpace.completedPlans.first?.steps.map(\.status), [.done, .done])
        XCTAssertNotNil(final.selectedSpace.completedPlans.first?.completedAt)
        XCTAssertEqual(final.selectedSpace.afterImageName, afterName)
        XCTAssertTrue(final.selectedSpace.hasVerifiedComparison)
        let restoredAfterURL = try XCTUnwrap(final.imageURL(for: afterName))
        XCTAssertNotNil(UIImage(contentsOfFile: restoredAfterURL.path))
        let disk = try XCTUnwrap(store.loadState()?.spaces.first(where: { $0.id == target.id }))
        XCTAssertEqual(disk.completedPlans.first?.id, plan.id)
        XCTAssertEqual(disk.afterImageName, afterName)
        XCTAssertNil(disk.activePlan)
        guard (testRun?.failureCount ?? 0) == 0 else { return }
        print("SMARTPAW_JSON_SPACE_RESTORE defaultSelectsFirst=true selectedByID=true pauseResume=true stepsPersist=true afterPhotoDecoded=true archived=true fixtureOnly=true")
    }

    func testCameraSizedJPEGIsDownsampledBeforeRecognition() throws {
        let source = try makeQuadrantImage(width: 4032, height: 3024)
        let data = try jpegData(source, orientation: 6)
        let image = try XCTUnwrap(UIImage.downsampled(data: data))
        let pixels = try XCTUnwrap(image.cgImage)

        XCTAssertEqual(image.scale, 1)
        XCTAssertEqual(image.imageOrientation, .up)
        XCTAssertEqual(pixels.width, 1536)
        XCTAssertEqual(pixels.height, 2048)
        XCTAssertLessThanOrEqual(pixels.bytesPerRow * pixels.height, 2048 * 2048 * 4)
        try assertCorners(pixels, equal: [.blue, .red, .yellow, .green])
    }

    func testEXIFRotationsAndMirrorsPreserveVisibleCorners() throws {
        let source = try makeQuadrantImage(width: 400, height: 300)
        for example in orientationExamples {
            try autoreleasepool {
                let image = try XCTUnwrap(UIImage.downsampled(
                    data: jpegData(source, orientation: example.exif), maxPixelSize: 200
                ))
                let pixels = try XCTUnwrap(image.cgImage)
                XCTAssertEqual(pixels.width, example.swapsAxes ? 150 : 200, "EXIF \(example.exif)")
                XCTAssertEqual(pixels.height, example.swapsAxes ? 200 : 150, "EXIF \(example.exif)")
                try assertCorners(pixels, equal: example.corners)
            }
        }
    }

    func testRecognitionNormalizationCapsLargeImagesInBothPaths() throws {
        let source = try makeQuadrantImage(width: 4032, height: 3024)
        for example in orientationExamples {
            try autoreleasepool {
                let image = UIImage(cgImage: source, scale: 3, orientation: example.ui)
                let detectorPixels = try XCTUnwrap(image.recognitionCGImage())
                let semanticPixels = try XCTUnwrap(image.normalizedCGImageForRecognition)
                for pixels in [detectorPixels, semanticPixels] {
                    XCTAssertEqual(pixels.width, example.swapsAxes ? 1536 : 2048)
                    XCTAssertEqual(pixels.height, example.swapsAxes ? 2048 : 1536)
                    XCTAssertLessThanOrEqual(pixels.bytesPerRow * pixels.height, 2048 * 2048 * 4)
                    try assertCorners(pixels, equal: example.corners)
                }
            }
        }
    }

    func testSmallImagesAreNotUpscaledByScreenOrImageScale() throws {
        let source = try makeQuadrantImage(width: 400, height: 300)
        let image = UIImage(cgImage: source, scale: 3, orientation: .rightMirrored)
        let pixels = try XCTUnwrap(image.recognitionCGImage())
        XCTAssertEqual(pixels.width, 300)
        XCTAssertEqual(pixels.height, 400)
        try assertCorners(pixels, equal: [.yellow, .green, .blue, .red])

        let upright = try XCTUnwrap(UIImage.downsampled(data: jpegData(source, orientation: 1)))
        XCTAssertEqual(upright.cgImage?.width, 400)
        XCTAssertEqual(upright.cgImage?.height, 300)
    }

    func testSemanticCropKeepsCoordinatesAfterLargeImageNormalization() throws {
        let source = try makeQuadrantImage(width: 4032, height: 3024)
        let image = UIImage(cgImage: source, scale: 3, orientation: .rightMirrored)
        let crop = try XCTUnwrap(image.cropped(to: CGRect(
            x: image.size.width * 0.05, y: image.size.height * 0.05,
            width: image.size.width * 0.3, height: image.size.height * 0.3
        )))
        let pixels = try XCTUnwrap(crop.cgImage)
        XCTAssertLessThanOrEqual(max(pixels.width, pixels.height), 2048)
        try assertCorners(pixels, equal: [.yellow, .yellow, .yellow, .yellow])
    }

    func testSemanticPixelBufferUsesRequestedPixelDimensions() throws {
        let source = try makeQuadrantImage(width: 4032, height: 3024)
        let image = UIImage(cgImage: source, scale: 3, orientation: .right)
        let buffer = try XCTUnwrap(image.centerCroppedPixelBuffer(size: CGSize(width: 256, height: 256)))
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 256)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), 256)
    }

    func testInvalidPhotoInputFailsWithoutAllocatingAnImage() throws {
        XCTAssertNil(UIImage.downsampled(data: Data()))
        XCTAssertNil(UIImage.downsampled(data: Data([0, 1, 2, 3])))
        let source = try makeQuadrantImage(width: 4, height: 3)
        let data = try jpegData(source, orientation: 1)
        XCTAssertNil(UIImage.downsampled(data: data, maxPixelSize: 0))
        XCTAssertNil(UIImage(cgImage: source).recognitionCGImage(maxPixelSize: 0))
    }

    private enum CornerColor: CaseIterable {
        case red, green, blue, yellow

        var components: [UInt8] {
            switch self {
            case .red: [255, 0, 0]
            case .green: [0, 255, 0]
            case .blue: [0, 0, 255]
            case .yellow: [255, 255, 0]
            }
        }

        var uiColor: UIColor {
            UIColor(red: CGFloat(components[0]) / 255, green: CGFloat(components[1]) / 255,
                    blue: CGFloat(components[2]) / 255, alpha: 1)
        }
    }

    private struct OrientationExample {
        let exif: Int
        let ui: UIImage.Orientation
        let swapsAxes: Bool
        let corners: [CornerColor]
    }

    private var orientationExamples: [OrientationExample] {
        [
            .init(exif: 1, ui: .up, swapsAxes: false, corners: [.red, .green, .blue, .yellow]),
            .init(exif: 2, ui: .upMirrored, swapsAxes: false, corners: [.green, .red, .yellow, .blue]),
            .init(exif: 3, ui: .down, swapsAxes: false, corners: [.yellow, .blue, .green, .red]),
            .init(exif: 4, ui: .downMirrored, swapsAxes: false, corners: [.blue, .yellow, .red, .green]),
            .init(exif: 5, ui: .leftMirrored, swapsAxes: true, corners: [.red, .blue, .green, .yellow]),
            .init(exif: 6, ui: .right, swapsAxes: true, corners: [.blue, .red, .yellow, .green]),
            .init(exif: 7, ui: .rightMirrored, swapsAxes: true, corners: [.yellow, .green, .blue, .red]),
            .init(exif: 8, ui: .left, swapsAxes: true, corners: [.green, .yellow, .red, .blue])
        ]
    }

    private func makeQuadrantImage(width: Int, height: Int) throws -> CGImage {
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return try XCTUnwrap(UIGraphicsImageRenderer(size: size, format: format).image { context in
            for (index, color) in [CornerColor.red, .green, .blue, .yellow].enumerated() {
                color.uiColor.setFill()
                context.fill(CGRect(x: CGFloat(index % 2) * size.width / 2,
                                    y: CGFloat(index / 2) * size.height / 2,
                                    width: size.width / 2, height: size.height / 2))
            }
        }.cgImage)
    }

    private func jpegData(_ image: CGImage, orientation: Int) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.9
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func assertCorners(_ image: CGImage, equal expected: [CornerColor],
                               file: StaticString = #filePath, line: UInt = #line) throws {
        for (index, expectedColor) in expected.enumerated() {
            let x = CGFloat(image.width) * (index % 2 == 0 ? 0.2 : 0.8)
            let y = CGFloat(image.height) * (index / 2 == 0 ? 0.2 : 0.8)
            let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)), file: file, line: line)
            var rgba = [UInt8](repeating: 0, count: 4)
            let drawn = rgba.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                              bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return false }
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                return true
            }
            XCTAssertTrue(drawn, file: file, line: line)
            for component in 0..<3 {
                XCTAssertLessThanOrEqual(abs(Int(rgba[component]) - Int(expectedColor.components[component])), 12,
                                         "Corner \(index), channel \(component)", file: file, line: line)
            }
        }
    }
}
