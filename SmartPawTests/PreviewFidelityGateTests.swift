import UIKit
import XCTest
@testable import SmartPaw

final class PreviewFidelityGateTests: XCTestCase {
    func testRejectedResultNeverBecomesRestorableCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: "PreviewGate.\(UUID().uuidString)")!
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
        let data = try png()
        do {
            _ = try await manager.persistValidatedGeneratedImage(data, cacheID: "rejected", validateResult: { _ in throw ImageGenerationError.fidelityFailed })
            XCTFail("Rejected image cannot save")
        } catch { XCTAssertEqual(error as? ImageGenerationError, .fidelityFailed) }
        XCTAssertNil(manager.cachedPreview(cacheID: "rejected"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("SmartPawGeneratedImages").path))
    }

    func testUncertainOrCancelledValidationNeverSaves() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: "PreviewGate.\(UUID().uuidString)")!
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
        for cancelled in [false, true] {
            do {
                _ = try await manager.persistValidatedGeneratedImage(png(), cacheID: "pending", validateResult: { _ in
                    if cancelled { throw CancellationError() }
                    throw ImageGenerationError.fidelityUnverified
                })
                XCTFail("No unchecked save")
            } catch { XCTAssertTrue(error is CancellationError || error as? ImageGenerationError == .fidelityUnverified) }
            XCTAssertNil(manager.cachedPreview(cacheID: "pending"))
        }
    }

    func testApprovedResultPersistsAfterReview() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let defaults = UserDefaults(suiteName: "PreviewGate.\(UUID().uuidString)")!
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = ImageGenerationManager(defaults: defaults, documentsDirectory: directory)
        let data = try png()
        let output = try await manager.persistValidatedGeneratedImage(data, cacheID: "approved", validateResult: { bytes in
            XCTAssertNotNil(UIImage(data: bytes))
        })
        XCTAssertEqual(manager.cachedPreview(cacheID: "approved"), output)
        XCTAssertNotNil(UIImage(contentsOfFile: output.path))
    }

    private func png() throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }.pngData())
    }
}
