import Foundation
import Security
import UIKit
import CryptoKit

struct ImageGenerationSettings: Codable, Equatable, Sendable {
    var enabled: Bool
    var provider: String
    var endpoint: String
    var model: String
    var size: String
    var quality: String
    var responseFormat: String
    var timeoutSeconds: Int

    static let disabled = ImageGenerationSettings(
        enabled: false,
        provider: "openai-compatible",
        endpoint: "",
        model: "",
        size: "1024x1024",
        quality: "standard",
        responseFormat: "b64_json",
        timeoutSeconds: 120
    )

    var validatedEndpoint: URL? {
        let raw = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil else { return nil }
        return url
    }

    var normalized: ImageGenerationSettings {
        ImageGenerationSettings(
            enabled: enabled,
            provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            size: size.trimmingCharacters(in: .whitespacesAndNewlines),
            quality: quality.trimmingCharacters(in: .whitespacesAndNewlines),
            responseFormat: responseFormat.trimmingCharacters(in: .whitespacesAndNewlines),
            timeoutSeconds: min(max(timeoutSeconds, 15), 300)
        )
    }
}

private struct ImageGenerationImportConfiguration: Decodable {
    var enabled: Bool
    var provider: String
    var endpoint: String
    var apiKey: String
    var model: String
    var size: String
    var quality: String
    var responseFormat: String
    var timeoutSeconds: Int

    var settings: ImageGenerationSettings {
        ImageGenerationSettings(
            enabled: enabled,
            provider: provider,
            endpoint: endpoint,
            model: model,
            size: size,
            quality: quality,
            responseFormat: responseFormat,
            timeoutSeconds: timeoutSeconds
        ).normalized
    }
}

enum ImageGenerationError: LocalizedError, Equatable {
    case notConfigured
    case invalidEndpoint
    case invalidInput
    case consentRequired
    case requestFailed(statusCode: Int)
    case invalidResponse
    case networkUnavailable
    case timedOut
    case cancelled
    case imageTooLarge
    case aspectRatioChanged
    case fidelityFailed
    case fidelityUnverified

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "整理效果图服务尚未配置，当前仍可使用本地整理方案。"
        case .invalidEndpoint:
            return "生图接口必须是有效的 HTTPS 地址。"
        case .invalidInput:
            return "原照片无法用于生成效果图，请重新拍摄。"
        case .consentRequired:
            return "请先同意上传当前空间照片，再生成整理效果图。"
        case .requestFailed(let statusCode):
            switch statusCode {
            case 401, 403: return "生图服务鉴权失败，请检查 API Key 和模型权限。"
            case 429: return "生图服务暂时限流或额度不足，请稍后重试。"
            default: return "生图服务请求失败（\(statusCode)），当前仍可继续使用本地整理方案。"
            }
        case .invalidResponse:
            return "生图服务没有返回可用图片，当前仍可继续使用本地整理方案。"
        case .networkUnavailable:
            return "暂时无法连接生图服务，请检查网络后重试。"
        case .timedOut:
            return "效果图生成超时，当前仍可继续使用本地整理方案。"
        case .cancelled:
            return "效果图生成已取消。"
        case .imageTooLarge:
            return "生图结果过大，未保存到设备。"
        case .fidelityFailed:
            return "效果图改变了原照片的物品或空间，未保存。可以重试或使用文字方案继续整理。"
        case .fidelityUnverified:
            return "暂时无法完成效果图保真复核，未保存。请检查AI视觉设置，或使用文字方案继续整理。"
        case .aspectRatioChanged:
            return "生图服务改变了原照片画幅，未保存为整理效果图。请保留原图并重新选择生成。"
        }
    }
}

enum StoragePreviewPrompt {
    static func make(planName: String, goal: String, changes: [String], itemNames: [String], focusZone: String = "") -> String {
        func clean(_ value: String, limit: Int) -> String {
            String(value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
        }
        let names = itemNames.map { clean($0, limit: 40) }.filter { !$0.isEmpty }
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        let inventory = counts.keys.sorted().map { "\($0) × \(counts[$0]!)" }.joined(separator: "；")
        let operations = changes.prefix(12).map { clean($0, limit: 160) }.filter { !$0.isEmpty }.joined(separator: "；")
        let scope = clean(focusZone, limit: 100)
        return """
        编辑输入图片，制作同一空间整理后的写实参考图。输入也可能是AI测试图，仍须逐件尊重实际可见内容。
        优先级最高的不变量：保持原相机角度、画幅比例、构图、桌面边界、墙地面、固定家具和光照方向。原有个人物品逐件保留，外观、颜色、尺寸与数量不可擅自改变；可以移动和排列，不能靠删除物品制造整洁。不要把笔、眼镜、线缆、小纸片或便签融掉、合并或变成装饰。未识别的小件也须按输入保留。移动是把原物从原位搬到目标位，不得在目标位复制一件却把原件留在原位。每一支笔、每一副眼镜、每一台设备的总数必须与输入完全一致。垃圾或包装也不可未经用户确认直接消失。
        仅作现实可行的分类和归位，保留可用工作区域。不得凭空增加家具、收纳盒、人物、文字标注、水印或界面；不要更换物品为相似新品，不要扩图、裁切、改装修或把房间变成样板间。
        方案：\(clean(planName, limit: 80))
        整理目标：\(clean(goal, limit: 280))
        主要操作：\(operations.isEmpty ? "同类集中、常用物品就近、适度留白" : operations)
        可见物品核对清单（识别结果可能不完整，以输入实际可见物品为准）：\(inventory.isEmpty ? "逐件检查输入图，保留所有可见物品" : inventory)
        \(scope.isEmpty ? "本次为整体整理参考图。" : "仅调整指定分区：" + scope + "。区域外的物品与空间位置保持不变，保持整体画幅以便前后对比。")
        在输出前检查遗漏和新增物品，优先物品保真与可执行性，其次才是美观。
        """
    }

    static func preferredSize(for imageData: Data, configured: String, model: String) -> String {
        guard model.caseInsensitiveCompare("gpt-image-2") == .orderedSame,
              let image = UIImage(data: imageData), let pixels = image.cgImage,
              pixels.width > 0, pixels.height > 0 else { return configured }
        let ratio = Double(pixels.width) / Double(pixels.height)
        guard ratio >= 1.0 / 3, ratio <= 3 else { return configured }
        if abs(ratio - 1) < 0.01 { return "1024x1024" }
        if ratio > 1 { return "1536x\(max(512, Int((1536 / ratio / 16).rounded()) * 16))" }
        return "\(max(512, Int((1536 * ratio / 16).rounded()) * 16))x1536"
    }
}

struct ImagePreviewRegion: Equatable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init?(x: Double, y: Double, width: Double, height: Double) {
        guard [x, y, width, height].allSatisfy(\.isFinite), x >= 0, y >= 0, width > 0, height > 0,
              x + width <= 1.000001, y + height <= 1.000001 else { return nil }
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

enum StoragePreviewImage {
    /// A model prompt cannot guarantee unchanged surroundings. Composite only the
    /// user-selected region, preserving source pixels everywhere else.
    static func validatedOutput(_ output: Data, source: Data, region: ImagePreviewRegion?) throws -> Data {
        guard let before = UIImage(data: source), let after = UIImage(data: output),
              before.size.width > 0, before.size.height > 0, after.size.width > 0, after.size.height > 0 else {
            throw ImageGenerationError.invalidResponse
        }
        let beforeRatio = before.size.width / before.size.height
        let afterRatio = after.size.width / after.size.height
        guard abs(afterRatio / beforeRatio - 1) <= 0.01 else { throw ImageGenerationError.aspectRatioChanged }
        guard let region else { return output }
        let size = CGSize(width: before.size.width * before.scale, height: before.size.height * before.scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let frame = CGRect(origin: .zero, size: size)
            before.draw(in: frame)
            context.cgContext.saveGState()
            context.cgContext.clip(to: CGRect(x: region.x * size.width, y: region.y * size.height,
                                              width: region.width * size.width, height: region.height * size.height))
            after.draw(in: frame)
            context.cgContext.restoreGState()
        }
        guard let composed = image.pngData() else { throw ImageGenerationError.invalidResponse }
        return composed
    }
}

struct ImageGenerationRequest: Sendable {
    var imageData: Data
    var prompt: String
    var settings: ImageGenerationSettings
    var apiKey: String
    var focusRegion: ImagePreviewRegion? = nil
}

struct ImageGenerationResult: Sendable {
    var imageData: Data
    var revisedPrompt: String?
}

final class OpenAICompatibleImageGenerationService: @unchecked Sendable {
    private let session: URLSession
    private let maximumResponseBytes = 25 * 1_024 * 1_024
    private let responseObserver: (@Sendable ([String: String]) -> Void)?

    init(session: URLSession = .shared, responseObserver: (@Sendable ([String: String]) -> Void)? = nil) {
        self.session = session
        self.responseObserver = responseObserver
    }

    func editImage(_ input: ImageGenerationRequest) async throws -> ImageGenerationResult {
        guard !input.imageData.isEmpty, !input.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImageGenerationError.invalidInput
        }
        var settings = input.settings.normalized
        settings.size = StoragePreviewPrompt.preferredSize(for: input.imageData, configured: settings.size, model: settings.model)
        guard settings.enabled,
              !settings.model.isEmpty,
              !input.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImageGenerationError.notConfigured
        }
        guard let endpoint = settings.validatedEndpoint else { throw ImageGenerationError.invalidEndpoint }

        let boundary = "SmartPaw-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(settings.timeoutSeconds)
        request.setValue("Bearer \(input.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var fields = [
            "model": settings.model,
            "prompt": input.prompt,
            "size": settings.size.isEmpty ? "1024x1024" : settings.size,
            "n": "1",
        ]
        if settings.model.caseInsensitiveCompare("gpt-image-2") != .orderedSame {
            if !settings.quality.isEmpty { fields["quality"] = settings.quality }
            if !settings.responseFormat.isEmpty { fields["response_format"] = settings.responseFormat }
        }
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            fields: fields,
            imageData: input.imageData
        )

        let (data, response) = try await perform(request)
        guard let http = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }
        if let responseObserver {
            // Shape-only diagnostics: never record prompts, credentials, image bytes,
            // provider messages, or signed download URLs.
            var diagnostics = ["status": String(http.statusCode), "response_bytes": String(data.count),
                               "content_type": http.mimeType ?? "unknown"]
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                diagnostics["has_data_array"] = String(object["data"] is [Any])
                diagnostics["has_error"] = String(object["error"] != nil)
                if let entries = object["data"] as? [[String: Any]] {
                    diagnostics["entry_count"] = String(entries.count)
                    if let first = entries.first {
                        diagnostics["base64_characters"] = String((first["b64_json"] as? String)?.count ?? 0)
                        diagnostics["has_download_url"] = String(first["url"] is String)
                    }
                }
            } else { diagnostics["json_object"] = "false" }
            responseObserver(diagnostics)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageGenerationError.requestFailed(statusCode: http.statusCode)
        }
        guard data.count <= maximumResponseBytes * 2 else { throw ImageGenerationError.imageTooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = object["data"] as? [[String: Any]],
              let first = entries.first else {
            throw ImageGenerationError.invalidResponse
        }

        let imageData: Data
        if let encoded = first["b64_json"] as? String,
           let decoded = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) {
            imageData = decoded
        } else if let rawURL = first["url"] as? String,
                  let url = URL(string: rawURL),
                  url.scheme?.lowercased() == "https",
                  url.user == nil, url.password == nil {
            var imageRequest = URLRequest(url: url)
            imageRequest.timeoutInterval = TimeInterval(settings.timeoutSeconds)
            let (downloaded, imageResponse) = try await perform(imageRequest)
            guard let imageHTTP = imageResponse as? HTTPURLResponse,
                  (200..<300).contains(imageHTTP.statusCode) else {
                throw ImageGenerationError.invalidResponse
            }
            imageData = downloaded
        } else {
            throw ImageGenerationError.invalidResponse
        }
        guard imageData.count <= maximumResponseBytes else { throw ImageGenerationError.imageTooLarge }
        guard UIImage(data: imageData) != nil else {
            throw ImageGenerationError.invalidResponse
        }
        return ImageGenerationResult(imageData: try StoragePreviewImage.validatedOutput(imageData, source: input.imageData, region: input.focusRegion), revisedPrompt: first["revised_prompt"] as? String)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw ImageGenerationError.cancelled
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw ImageGenerationError.cancelled
            case .timedOut:
                throw ImageGenerationError.timedOut
            default:
                throw ImageGenerationError.networkUnavailable
            }
        } catch {
            throw ImageGenerationError.networkUnavailable
        }
    }

    private static func multipartBody(boundary: String, fields: [String: String], imageData: Data) -> Data {
        var body = Data()
        let newline = "\r\n"
        for key in fields.keys.sorted() {
            body.appendUTF8("--\(boundary)\(newline)")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(key)\"\(newline)\(newline)")
            body.appendUTF8(fields[key] ?? "")
            body.appendUTF8(newline)
        }
        body.appendUTF8("--\(boundary)\(newline)")
        body.appendUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"space.jpg\"\(newline)")
        body.appendUTF8("Content-Type: image/jpeg\(newline)\(newline)")
        body.append(imageData)
        body.appendUTF8(newline)
        body.appendUTF8("--\(boundary)--\(newline)")
        return body
    }

}

final class ImageGenerationManager: @unchecked Sendable {
    static let shared = ImageGenerationManager()

    private let settingsKey = "SmartPaw.imageGeneration.settings"
    private let consentedEndpointKey = "SmartPaw.imageGeneration.consentedEndpoint"
    private let defaults: UserDefaults
    private let service: OpenAICompatibleImageGenerationService
    private let fileManager: FileManager
    private let documentsDirectoryOverride: URL?
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        service: OpenAICompatibleImageGenerationService = OpenAICompatibleImageGenerationService(),
        fileManager: FileManager = .default,
        documentsDirectory: URL? = nil
    ) {
        self.defaults = defaults
        self.service = service
        self.fileManager = fileManager
        self.documentsDirectoryOverride = documentsDirectory
    }

    var settings: ImageGenerationSettings {
        lock.withLock {
            guard let data = defaults.data(forKey: settingsKey),
                  let value = try? JSONDecoder().decode(ImageGenerationSettings.self, from: data) else { return .disabled }
            return value.normalized
        }
    }

    var hasAPIKey: Bool { !(ImageGenerationKeychainStore.loadAPIKey() ?? "").isEmpty }

    var hasConsentForCurrentEndpoint: Bool {
        let endpoint = settings.endpoint
        guard !endpoint.isEmpty else { return false }
        return defaults.string(forKey: consentedEndpointKey) == endpoint
    }

    func grantConsentForCurrentEndpoint() {
        let endpoint = settings.endpoint
        guard !endpoint.isEmpty else { return }
        defaults.set(endpoint, forKey: consentedEndpointKey)
        writeDiagnostics(event: "consent-granted", detail: "")
    }

    func statusObject() -> [String: Any] {
        let current = settings
        return [
            "enabled": current.enabled,
            "configured": current.enabled && current.validatedEndpoint != nil && !current.model.isEmpty && hasAPIKey,
            "hasAPIKey": hasAPIKey,
            "hasConsent": hasConsentForCurrentEndpoint,
            "provider": current.provider,
            "endpointHost": current.validatedEndpoint?.host ?? "",
            "model": current.model,
            "size": current.size,
        ]
    }

    func generatePreview(imageData: Data, prompt: String, cacheID: String, focusRegion: ImagePreviewRegion? = nil, validateResult: (@Sendable (Data) async throws -> Void)? = nil) async throws -> URL {
        let current = settings
        guard current.enabled, current.validatedEndpoint != nil,
              let key = ImageGenerationKeychainStore.loadAPIKey(), !key.isEmpty else {
            throw ImageGenerationError.notConfigured
        }
        guard hasConsentForCurrentEndpoint else {
            throw ImageGenerationError.consentRequired
        }
        do {
            let result = try await service.editImage(ImageGenerationRequest(
                imageData: imageData,
                prompt: prompt,
                settings: current,
                apiKey: key,
                focusRegion: focusRegion
            ))
            try Task.checkCancellation()
            let output = try await persistValidatedGeneratedImage(result.imageData, cacheID: Self.fingerprintedCacheID(
                cacheID, imageData: imageData, prompt: prompt
            ), validateResult: validateResult)
            writeDiagnostics(event: "generation-succeeded", detail: "bytes=\(result.imageData.count)")
            return output
        } catch {
            writeDiagnostics(event: "generation-failed", detail: Self.safeErrorDescription(error))
            throw error
        }
    }

    /// Return a verified on-device preview for the same space and plan after a relaunch.
    func cachedPreview(cacheID: String) -> URL? {
        let prefix = "preview-\(safeCacheID(cacheID))-"
        let candidates = (try? fileManager.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return candidates
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension.lowercased() == "jpg" }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
            .first { UIImage(contentsOfFile: $0.path) != nil }
    }

    func cachedPreview(cacheID: String, imageData: Data, prompt: String) -> URL? {
        cachedPreview(cacheID: Self.fingerprintedCacheID(cacheID, imageData: imageData, prompt: prompt))
    }

    static func fingerprintedCacheID(_ cacheID: String, imageData: Data, prompt: String) -> String {
        var hasher = SHA256()
        hasher.update(data: imageData)
        hasher.update(data: Data(prompt.utf8))
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "\(cacheID)-\(digest)"
    }

    @discardableResult
    func reset() -> Bool {
        let removedKey = ImageGenerationKeychainStore.deleteAPIKey()
        guard removedKey else {
            writeDiagnostics(event: "reset-failed", detail: "keychain-delete-failed")
            return false
        }
        defaults.removeObject(forKey: settingsKey)
        defaults.removeObject(forKey: consentedEndpointKey)
        try? fileManager.removeItem(at: cacheDirectory)
        writeDiagnostics(event: "reset", detail: removedKey ? "" : "keychain-delete-failed")
        return removedKey
    }

    #if DEBUG
    func importDebugConfigurationIfRequested(arguments: [String] = CommandLine.arguments) {
        guard arguments.contains("--import-image-generation-config") else { return }
        let inputURL = documentsDirectory.appendingPathComponent("image-generation-import.json")
        do {
            let data = try Data(contentsOf: inputURL)
            let imported = try JSONDecoder().decode(ImageGenerationImportConfiguration.self, from: data)
            let newSettings = imported.settings
            guard newSettings.validatedEndpoint != nil,
                  !newSettings.model.isEmpty,
                  !imported.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ImageGenerationError.notConfigured
            }
            guard ImageGenerationKeychainStore.saveAPIKey(imported.apiKey) else {
                throw CocoaError(.fileWriteNoPermission)
            }
            let oldEndpoint = settings.endpoint
            let settingsData = try JSONEncoder().encode(newSettings)
            defaults.set(settingsData, forKey: settingsKey)
            if oldEndpoint != newSettings.endpoint {
                defaults.removeObject(forKey: consentedEndpointKey)
            }
            try fileManager.removeItem(at: inputURL)
            writeDiagnostics(event: "debug-import-succeeded", detail: "")
        } catch {
            writeDiagnostics(event: "debug-import-failed", detail: Self.safeErrorDescription(error))
        }
    }
    #endif

    private var documentsDirectory: URL {
        documentsDirectoryOverride ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var cacheDirectory: URL {
        documentsDirectory.appendingPathComponent("SmartPawGeneratedImages", isDirectory: true)
    }

    /// Review before cache persistence; failure/cancellation cannot leave a restorable preview.
    func persistValidatedGeneratedImage(_ data: Data, cacheID: String,
                                       validateResult: (@Sendable (Data) async throws -> Void)?) async throws -> URL {
        try Task.checkCancellation()
        if let validateResult { try await validateResult(data) }
        try Task.checkCancellation()
        return try persistGeneratedImage(data, cacheID: cacheID)
    }

    func persistGeneratedImage(_ data: Data, cacheID: String) throws -> URL {
        guard let image = UIImage(data: data) else { throw ImageGenerationError.invalidResponse }
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let safeID = Self.safeCacheID(cacheID)
        let outputURL = cacheDirectory.appendingPathComponent("preview-\(safeID)-\(UUID().uuidString).jpg")
        guard let normalized = image.jpegData(compressionQuality: 0.88) else {
            throw ImageGenerationError.invalidResponse
        }
        try normalized.write(to: outputURL, options: [.atomic, .completeFileProtection])
        for candidate in (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
            where candidate != outputURL && candidate.lastPathComponent.hasPrefix("preview-\(safeID)-") {
            try? fileManager.removeItem(at: candidate)
        }
        return outputURL
    }

    private static func safeCacheID(_ cacheID: String) -> String {
        let value = cacheID.replacingOccurrences(of: "[^A-Za-z0-9-]", with: "-", options: .regularExpression)
        return value.isEmpty ? "preview" : value
    }

    private func safeCacheID(_ cacheID: String) -> String { Self.safeCacheID(cacheID) }

    private func writeDiagnostics(event: String, detail: String) {
        let current = settings
        let lines = [
            "time=\(ISO8601DateFormatter().string(from: Date()))",
            "event=\(event)",
            "enabled=\(current.enabled)",
            "configured=\(current.enabled && current.validatedEndpoint != nil && !current.model.isEmpty && hasAPIKey)",
            "endpointHost=\(current.validatedEndpoint?.host ?? "")",
            "model=\(current.model)",
            "hasConsent=\(hasConsentForCurrentEndpoint)",
            "detail=\(detail)",
        ].joined(separator: "\n")
        try? lines.write(
            to: documentsDirectory.appendingPathComponent("smartpaw-image-generation-diagnostics.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func safeErrorDescription(_ error: Error) -> String {
        guard let error = error as? ImageGenerationError else { return "network-error" }
        switch error {
        case .notConfigured: return "not-configured"
        case .invalidEndpoint: return "invalid-endpoint"
        case .invalidInput: return "invalid-input"
        case .consentRequired: return "consent-required"
        case .requestFailed(let statusCode): return "http-\(statusCode)"
        case .invalidResponse: return "invalid-response"
        case .networkUnavailable: return "network-error"
        case .timedOut: return "timeout"
        case .cancelled: return "cancelled"
        case .imageTooLarge: return "image-too-large"
        case .fidelityFailed: return "fidelity-failed"
        case .fidelityUnverified: return "fidelity-unverified"
        case .aspectRatioChanged: return "aspect-ratio-changed"
        }
    }
}

private enum ImageGenerationKeychainStore {
    private static let service = "com.qszjlzz.smartpaw.image-generation"
    private static let account = "api-key"

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func saveAPIKey(_ rawKey: String) -> Bool {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let value = Data(key.utf8)
        let update = SecItemUpdate(base as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if update == errSecSuccess { return true }
        var insert = base
        insert[kSecValueData as String] = value
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
