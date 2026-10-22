import Foundation
import UIKit
import XCTest
@testable import SmartPaw

final class DisorderAssessmentTests: XCTestCase {
    private let tidy = #"{"score":12,"level":"tidy","evidence":["物品排列整齐，台面可用"],"clutterRegions":[],"estimatedMinutes":2}"#

    func testTidyAssessmentHasNoFabricatedRegions() throws {
        let value = try CloudVisionRecognitionService.validatedDisorder(from: tidy)
        XCTAssertEqual(value.score, 12)
        XCTAssertEqual(value.level, .tidy)
        XCTAssertTrue(value.clutterRegions.isEmpty)
    }

    func testMissingOrUnavailableResponseDoesNotInventScore() {
        for input in ["unavailable", "{}", #"{"unavailable":true}"#, tidy.replacingOccurrences(of: #""score":12,"#, with: ""), tidy.replacingOccurrences(of: #""clutterRegions":[],"#, with: "")] {
            XCTAssertThrowsError(try CloudVisionRecognitionService.validatedDisorder(from: input))
        }
    }

    func testStrictNumericAndEvidenceValidation() {
        for input in [tidy.replacingOccurrences(of: ":12", with: ":101"), tidy.replacingOccurrences(of: ":12", with: ":-1"), tidy.replacingOccurrences(of: ":12", with: ":true"), tidy.replacingOccurrences(of: ":12", with: #": "12""#), tidy.replacingOccurrences(of: "tidy", with: "perfect"), tidy.replacingOccurrences(of: "物品排列整齐，台面可用", with: "  "), tidy.replacingOccurrences(of: ":2}", with: ":241}")] {
            XCTAssertThrowsError(try CloudVisionRecognitionService.validatedDisorder(from: input))
        }
    }

    func testRegionsMustBeWithinPhotoAndHaveEvidence() throws {
        let region = #"{"x":0.1,"y":0.2,"width":0.3,"height":0.4,"label":"纸张无序堆叠"}"#
        let valid = tidy.replacingOccurrences(of: #""clutterRegions":[]"#, with: #""clutterRegions":["# + region + "]")
        let value = try CloudVisionRecognitionService.validatedDisorder(from: valid)
        XCTAssertEqual(value.clutterRegions.first?.x, 0.1)
        for invalid in [region.replacingOccurrences(of: ":0.1", with: ":-0.1"), region.replacingOccurrences(of: ":0.3", with: ":0.95"), region.replacingOccurrences(of: ":0.4", with: ":0"), region.replacingOccurrences(of: "纸张无序堆叠", with: "")] {
            XCTAssertThrowsError(try CloudVisionRecognitionService.validatedDisorder(from: valid.replacingOccurrences(of: region, with: invalid)))
        }
    }

    func testConsentAndConfigurationPreventAnyRequest() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DisorderProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let service = CloudVisionRecognitionService(session: session)
        for settings in [LLMSettings.default, LLMSettings(isEnabled: true, endpoint: "https://vision.invalid", apiKey: "fixture", model: "fixture", hasCloudConsent: false)] {
            do { _ = try await service.assessDisorder(image: UIImage(), settings: settings); XCTFail("Expected no request") }
            catch { guard case CloudVisionError.notConfigured = error else { return XCTFail("Expected configuration gate") } }
        }
    }

    func testConfiguredEmptyImageIsRejectedBeforeNetwork() async {
        let settings = LLMSettings(isEnabled: true, endpoint: "https://vision.invalid", apiKey: "fixture", model: "fixture-model", hasCloudConsent: true)
        do { _ = try await CloudVisionRecognitionService().assessDisorder(image: UIImage(), settings: settings); XCTFail("Expected invalid image") }
        catch { guard case CloudVisionError.invalidImage = error else { return XCTFail("Expected invalid image") } }
    }

    func testConfiguredServiceSendsImageAndVisualCriteria() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DisorderProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        let settings = LLMSettings(isEnabled: true, endpoint: "https://vision.invalid", apiKey: "fixture", model: "fixture-model", hasCloudConsent: true)
        let result = try await CloudVisionRecognitionService(session: session).assessDisorder(image: image, settings: settings)
        XCTAssertEqual(result.score, 12)
        XCTAssertEqual(result.level, .tidy)
    }

    func testProductionAIPhotoAssessmentOptIn() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SMARTPAW_RUN_AI_DISORDER"] == "1", let imagePath = env["SMARTPAW_RECOGNITION_IMAGE_PATH"],
              let configPath = env["SMARTPAW_VISION_CONFIG_PATH"], let reportPath = env["SMARTPAW_DISORDER_REPORT_PATH"] else {
            throw XCTSkip("One explicitly enabled AI development-photo request; no camera.")
        }
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: configPath))) as? [String: Any])
        let settings = LLMSettings(isEnabled: true, endpoint: try XCTUnwrap(config["endpoint"] as? String), apiKey: try XCTUnwrap(config["apiKey"] as? String), model: try XCTUnwrap(config["model"] as? String), hasCloudConsent: true)
        let image = try XCTUnwrap(UIImage.downsampled(data: Data(contentsOf: URL(fileURLWithPath: imagePath))))
        let start = Date()
        let assessment = try await CloudVisionRecognitionService().assessDisorder(image: image, settings: settings)
        var report = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(assessment)) as? [String: Any])
        report["source_type"] = "synthetic_development"
        report["real_holdout"] = false
        report["network_requests"] = 1
        report["camera_used"] = false
        report["elapsed_seconds"] = Date().timeIntervalSince(start)
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: reportPath), options: .atomic)
    }
}

private final class DisorderProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "vision.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.timeoutInterval, 90)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture")
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; body.append(contentsOf: buffer.prefix(n)) }
        }
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        let messages = object?["messages"] as? [[String: Any]]
        let content = messages?.first?["content"] as? [[String: Any]]
        XCTAssertTrue((content?.first?["text"] as? String)?.contains("物品多不等于混乱") == true)
        let image = content?.last?["image_url"] as? [String: Any]
        XCTAssertTrue((image?["url"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true)
        XCTAssertEqual(image?["detail"] as? String, "high")
        XCTAssertEqual(object?["model"] as? String, "fixture-model")
        let value = #"{"score":12,"level":"tidy","evidence":["物品整齐"],"clutterRegions":[],"estimatedMinutes":2}"#
        let response = try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": value]]]])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
