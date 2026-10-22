import CryptoKit
import Foundation
import UIKit
import XCTest
@testable import SmartPaw

final class PreviewFidelityTests: XCTestCase {
    func testValidVerdictsRequireConsistentVisibleEvidence() throws {
        let passed = try CloudVisionRecognitionService.validatedPreviewFidelity(from: #"{"verdict":"pass","issues":[]}"#)
        XCTAssertEqual(passed, PreviewFidelityAssessment(verdict: .pass, issues: []))
        let failed = try CloudVisionRecognitionService.validatedPreviewFidelity(from: #"{"verdict":"fail","issues":["夹板金属夹从一个变为两个"]}"#)
        XCTAssertEqual(failed.verdict, .fail)
        let uncertain = try CloudVisionRecognitionService.validatedPreviewFidelity(from: #"{"verdict":"uncertain","issues":["遮挡后无法核实黑笔数量"]}"#)
        XCTAssertEqual(uncertain.verdict, .uncertain)
        XCTAssertEqual(try JSONDecoder().decode(PreviewFidelityAssessment.self, from: JSONEncoder().encode(failed)), failed)
    }

    func testMissingMalformedOrContradictoryVerdictNeverPasses() {
        for input in [
            "unavailable", "{}", #"{"verdict":"pass"}"#, #"{"issues":[]}"#,
            #"{"verdict":true,"issues":[]}"#, #"{"verdict":"perfect","issues":[]}"#,
            #"{"verdict":"pass","issues":["多出一支笔"]}"#,
            #"{"verdict":"fail","issues":[]}"#, #"{"verdict":"uncertain","issues":[]}"#,
            #"{"verdict":"fail","issues":["  " ]}"#,
            #"{"verdict":"fail","issues":[1]}"#, #"{"verdict":"fail","issues":"duplicated"}"#
        ] {
            XCTAssertThrowsError(try CloudVisionRecognitionService.validatedPreviewFidelity(from: input), input)
        }
    }

    func testEvidenceIsBoundedAndRequiredWithoutFallback() throws {
        for issues in [Array(repeating: "金属夹重复", count: 9), [String(repeating: "物", count: 201)]] {
            let data = try JSONSerialization.data(withJSONObject: ["verdict": "fail", "issues": issues])
            XCTAssertThrowsError(try CloudVisionRecognitionService.validatedPreviewFidelity(from: String(decoding: data, as: UTF8.self)))
        }
    }

    func testConsentAndConfigurationBlockBothImageUploads() async {
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        let initial = PreviewFidelityRequestLog.shared.count
        let service = CloudVisionRecognitionService(session: session)
        var settings = configuredSettings(endpoint: "https://fidelity.invalid/v1/chat/completions")
        settings.hasCloudConsent = false
        var disabled = settings; disabled.hasCloudConsent = true; disabled.isEnabled = false
        var missingKey = settings; missingKey.hasCloudConsent = true; missingKey.apiKey = ""
        for value in [LLMSettings.default, settings, disabled, missingKey] {
            do {
                _ = try await service.reviewPreview(source: fixtureImage(.red), preview: fixtureImage(.blue), settings: value)
                XCTFail("Consent/configuration gate must reject before uploading either image")
            } catch {
                guard case CloudVisionError.notConfigured = error else { XCTFail("Expected configuration gate"); continue }
            }
        }
        XCTAssertEqual(PreviewFidelityRequestLog.shared.count, initial)
    }

    func testInvalidImageAndCancellationDoNotUpload() async {
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        let initial = PreviewFidelityRequestLog.shared.count
        let settings = configuredSettings(endpoint: "https://fidelity.invalid/v1/chat/completions")
        let service = CloudVisionRecognitionService(session: session)
        do {
            _ = try await service.reviewPreview(source: fixtureImage(.red), preview: UIImage(), settings: settings)
            XCTFail("Invalid preview cannot be uploaded")
        } catch {
            guard case CloudVisionError.invalidImage = error else { return XCTFail("Expected invalid image") }
        }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.reviewPreview(source: fixtureImage(.red), preview: fixtureImage(.blue), settings: settings)
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(PreviewFidelityRequestLog.shared.count, initial)
    }

    func testChatAndResponsesUploadTwoActualImagesInSourceThenPreviewOrder() async throws {
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        for endpoint in ["https://fidelity.invalid/v1/chat/completions", "https://fidelity.invalid/v1/responses"] {
            let result = try await CloudVisionRecognitionService(session: session).reviewPreview(
                source: fixtureImage(.red), preview: fixtureImage(.blue), settings: configuredSettings(endpoint: endpoint))
            XCTAssertEqual(result.verdict, .fail)
            XCTAssertEqual(result.issues, ["夹板金属夹从一个变为两个"])
        }
    }

    func testExistingSingleImageRecognitionStillUploadsExactlyOneImage() async throws {
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        for endpoint in ["https://fidelity.invalid/single/chat/completions", "https://fidelity.invalid/single/responses"] {
            let result = try await CloudVisionRecognitionService(session: session).recognize(
                image: fixtureImage(.red), settings: configuredSettings(endpoint: endpoint))
            XCTAssertTrue(result.isEmpty)
        }
    }

    /// Exactly one explicit real review of a synthetic pair, never an image edit.
    func testProductionAIPreviewFidelityOptIn() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SMARTPAW_RUN_AI_FIDELITY"] == "1",
              let sourcePath = env["SMARTPAW_RECOGNITION_IMAGE_PATH"],
              let previewPath = env["SMARTPAW_FIDELITY_PREVIEW_PATH"],
              let configPath = env["SMARTPAW_VISION_CONFIG_PATH"],
              let reportPath = env["SMARTPAW_FIDELITY_REPORT_PATH"] else {
            throw XCTSkip("Explicit opt-in required for one synthetic-pair fidelity review; no camera/edit request.")
        }
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: configPath))) as? [String: Any])
        let settings = LLMSettings(isEnabled: true, endpoint: try XCTUnwrap(config["endpoint"] as? String),
                                   apiKey: try XCTUnwrap(config["apiKey"] as? String), model: try XCTUnwrap(config["model"] as? String), hasCloudConsent: true)
        let sourceData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
        let previewData = try Data(contentsOf: URL(fileURLWithPath: previewPath))
        let source = try XCTUnwrap(UIImage.downsampled(data: sourceData))
        let preview = try XCTUnwrap(UIImage.downsampled(data: previewData))
        let started = Date()
        let reportURL = URL(fileURLWithPath: reportPath)
        try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var report: [String: Any] = [
            "source_type": "synthetic_development", "real_holdout": false, "camera_used": false,
            "review_requests": 1, "image_generation_requests": 0,
            "source_sha256": SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined(),
            "preview_sha256": SHA256.hash(data: previewData).map { String(format: "%02x", $0) }.joined(),
            "known_visual_issue": "clipboard metal clip duplicated from one to two",
            "review_is_not_fidelity_guarantee": true
        ]
        do {
            let result = try await CloudVisionRecognitionService().reviewPreview(source: source, preview: preview, settings: settings)
            report["assessment"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result))
            report["elapsed_seconds"] = Date().timeIntervalSince(started)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic)
            XCTAssertNotEqual(result.verdict, .pass, "The known duplicated metal clip must not receive a pass; preserve the provider verdict in the report.")
        } catch {
            report["elapsed_seconds"] = Date().timeIntervalSince(started)
            // Do not retain provider raw text, endpoint, key, image data or transport descriptions.
            report["review_status"] = error is CancellationError ? "cancelled" : "request_or_validation_failed"
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic)
            throw error
        }
    }

    private func configuredSettings(endpoint: String) -> LLMSettings {
        LLMSettings(isEnabled: true, endpoint: endpoint, apiKey: "fixture", model: "fixture-model", hasCloudConsent: true)
    }

    private func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PreviewFidelityProtocol.self]
        return URLSession(configuration: config)
    }
}

private func fixtureImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
        color.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
    }
}

private final class PreviewFidelityRequestLog: @unchecked Sendable {
    static let shared = PreviewFidelityRequestLog()
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    func increment() { lock.lock(); defer { lock.unlock() }; value += 1 }
}

private final class PreviewFidelityProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fidelity.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        PreviewFidelityRequestLog.shared.increment()
        do {
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 90)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture")
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(object["model"] as? String, "fixture-model")
            let chat = request.url?.path.contains("chat/completions") == true
            let single = request.url?.path.contains("single") == true
            let messages = try XCTUnwrap(object[chat ? "messages" : "input"] as? [[String: Any]])
            let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
            XCTAssertEqual(content.count, single ? 2 : 3)
            XCTAssertEqual(content.first?["type"] as? String, chat ? "text" : "input_text")
            if !single {
                let prompt = try XCTUnwrap(content.first?["text"] as? String)
                XCTAssertTrue(prompt.contains("图片1是原始照片，图片2是建议的整理效果图"))
                XCTAssertTrue(prompt.contains("金属夹"))
                XCTAssertTrue(prompt.contains("uncertain"))
            }
            for (index, part) in content.dropFirst().enumerated() {
                XCTAssertEqual(part["type"] as? String, chat ? "image_url" : "input_image")
                let url: String
                if chat {
                    let image = try XCTUnwrap(part["image_url"] as? [String: Any])
                    XCTAssertEqual(image["detail"] as? String, "high")
                    url = try XCTUnwrap(image["url"] as? String)
                } else { url = try XCTUnwrap(part["image_url"] as? String) }
                let prefix = "data:image/jpeg;base64,"
                XCTAssertTrue(url.hasPrefix(prefix))
                let data = try XCTUnwrap(Data(base64Encoded: String(url.dropFirst(prefix.count))))
                let image = try XCTUnwrap(UIImage(data: data)?.cgImage)
                XCTAssertEqual(image.width, 40); XCTAssertEqual(image.height, 30)
                var pixel = [UInt8](repeating: 0, count: 4)
                let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                // Source is red; preview is blue. Decode the actual uploaded data to prove ordering.
                if index == 0 { XCTAssertGreaterThan(pixel[0], 240); XCTAssertLessThan(pixel[2], 15) }
                else { XCTAssertGreaterThan(pixel[2], 240); XCTAssertLessThan(pixel[0], 15) }
            }
            let result = single ? #"{"items":[]}"# : #"{"verdict":"fail","issues":["夹板金属夹从一个变为两个"]}"#
            let envelope: [String: Any] = chat ? ["choices": [["message": ["content": result]]]] : ["output_text": result]
            let response = try JSONSerialization.data(withJSONObject: envelope)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
