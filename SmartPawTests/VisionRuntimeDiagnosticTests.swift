import UIKit
import XCTest
@testable import SmartPaw

final class VisionRuntimeDiagnosticTests: XCTestCase {
    func testFailureDiagnosticOmitsNSErrorUserInfo() throws {
        let error = NSError(domain: "com.apple.Vision", code: 9, userInfo: [
            NSLocalizedDescriptionKey: "private-photo-text",
            NSUnderlyingErrorKey: NSError(domain: "private-endpoint", code: 1),
            "apiKey": "private-key"
        ])
        let diagnostic = VisionScanService.Diagnostic.failure(stage: .classification, error: error)
        let data = try JSONEncoder().encode(diagnostic)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(diagnostic.errorDomain, "com.apple.Vision")
        XCTAssertEqual(diagnostic.errorCode, 9)
        XCTAssertEqual(Set(json.keys), Set(["stage", "state", "errorDomain", "errorCode"]))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("private-"))
    }

    func testInvalidImageReportsNormalizationFailureWithoutStartingVision() async throws {
        let recorder = DiagnosticRecorder()
        let service = VisionScanService(diagnosticObserver: recorder.record)

        do {
            _ = try await service.scanImage(UIImage())
            XCTFail("Expected invalidImage")
        } catch {
            XCTAssertTrue(error is ScanError)
        }

        let diagnostics = recorder.snapshot()
        XCTAssertEqual(diagnostics.map(\.stage), [.scan, .imageNormalization, .scan])
        XCTAssertEqual(diagnostics.map(\.state), [.started, .failed, .failed])
    }

    func testBundledPhotoReportsRuntimeFailuresAndRecognitionCounts() async throws {
        let recorder = DiagnosticRecorder()
        let service = VisionScanService(diagnosticObserver: recorder.record)
        let image = try XCTUnwrap(UIImage(named: AppSampleAssets.messyDesk))

        let items = try await service.scanImage(image)
        let diagnostics = recorder.snapshot()
        let report = RuntimeReport(diagnostics: diagnostics, finalItemCount: items.count)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(report)
        print("SMARTPAW_VISION_RUNTIME_DIAGNOSTIC \(String(decoding: data, as: UTF8.self))")
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "vision-runtime-diagnostic"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertEqual(diagnostics.first?.stage, .scan)
        XCTAssertEqual(diagnostics.first?.state, .started)
        XCTAssertEqual(diagnostics.last?.stage, .scan)
        XCTAssertEqual(diagnostics.last?.state, .completed)
        XCTAssertEqual(diagnostics.last?.outputCount, items.count)
        for stage in [VisionScanService.Diagnostic.Stage.classification, .textRecognition,
                      .foregroundSegmentation, .saliencyAndRectangles, .visualRegions] {
            XCTAssertTrue(diagnostics.contains { $0.stage == stage && $0.state == .started }, "Missing start: \(stage)")
            let terminal = diagnostics.filter { $0.stage == stage && $0.state != .started }
            XCTAssertEqual(terminal.count, 1, "Missing or duplicate completion: \(stage)")
            if let diagnostic = terminal.first {
                if diagnostic.state == .failed {
                    XCTAssertNotNil(diagnostic.errorDomain)
                    XCTAssertNotNil(diagnostic.errorCode)
                } else {
                    XCTAssertNotNil(diagnostic.outputCount)
                }
            }
        }
        for diagnostic in diagnostics {
            if let count = diagnostic.observationCount { XCTAssertGreaterThanOrEqual(count, 0) }
            if let count = diagnostic.eligibleObservationCount { XCTAssertGreaterThanOrEqual(count, 0) }
            if let count = diagnostic.outputCount { XCTAssertGreaterThanOrEqual(count, 0) }
        }
    }

    private struct RuntimeReport: Encodable {
        let diagnostics: [VisionScanService.Diagnostic]
        let finalItemCount: Int
    }

    private final class DiagnosticRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var diagnostics: [VisionScanService.Diagnostic] = []

        func record(_ diagnostic: VisionScanService.Diagnostic) {
            lock.lock()
            defer { lock.unlock() }
            diagnostics.append(diagnostic)
        }

        func snapshot() -> [VisionScanService.Diagnostic] {
            lock.lock()
            defer { lock.unlock() }
            return diagnostics
        }
    }
}
