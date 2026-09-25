import Foundation
import UIKit

enum CloudVisionError: LocalizedError {
    case notConfigured
    case invalidImage
    case transport(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "未配置可用的云端识别服务。"
        case .invalidImage:
            return "照片无法编码上传。"
        case .transport(let detail):
            return "云端识别请求失败：\(detail)"
        case .invalidResponse(let detail):
            return "云端识别返回无法解析：\(detail)"
        }
    }
}

/// 把照片交给已配置的多模态大模型做识别。
///
/// 本地 CoreML 管线在真机上可能因为模型编译失败或阈值过严而返回空结果，
/// 这条路径用于保证"拍完一定认得出东西"：模型直接输出中文物品名、类别和
/// 大致位置，比本地小模型更贴近日用品场景，也不需要改动任何界面。
struct CloudVisionRecognitionService: Sendable {
    /// 上传前把长边压到这个尺寸：视觉模型在这个分辨率下就够用，流量和延迟都更可控。
    private static let maxImageEdge: CGFloat = 1024
    private static let timeout: TimeInterval = 45

    func recognize(image: UIImage, settings: LLMSettings) async throws -> [DetectedItem] {
        guard settings.canRequestVision else { throw CloudVisionError.notConfigured }
        guard let imageData = Self.jpegData(for: image) else { throw CloudVisionError.invalidImage }
        let text = try await send(prompt: Self.prompt, imageData: imageData, settings: settings)
        return Self.items(from: text)
    }

    // MARK: - 网络

    private func send(prompt: String, imageData: Data, settings: LLMSettings) async throws -> String {
        guard let target = Self.requestTarget(for: settings) else {
            throw CloudVisionError.transport("接口地址无法解析")
        }
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var request = URLRequest(url: target.url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        if target.chatCompletions {
            let parts: [[String: Any]] = [
                ["type": "text", "text": prompt],
                [
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(imageData.base64EncodedString())"]
                ]
            ]
            let payload: [String: Any] = [
                "model": settings.resolvedVisionModel,
                "temperature": 0.2,
                "max_tokens": 1500,
                "messages": [["role": "user", "content": parts]]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } else {
            let content = [
                CloudVisionInputContent(type: "input_text", text: prompt, imageURL: nil),
                CloudVisionInputContent(
                    type: "input_image",
                    text: nil,
                    imageURL: "data:image/jpeg;base64,\(imageData.base64EncodedString())"
                )
            ]
            request.httpBody = try JSONEncoder().encode(CloudVisionRequest(
                model: settings.resolvedVisionModel,
                input: [CloudVisionInputMessage(role: "user", content: content)]
            ))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CloudVisionError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let serverText = String(data: data, encoding: .utf8) ?? ""
            print("SMARTPAW_VISION_HTTP \(http.statusCode) \(serverText.prefix(400))")
            throw CloudVisionError.transport("HTTP \(http.statusCode)")
        }
        return try Self.responseText(from: data, chatCompletions: target.chatCompletions)
    }

    /// 兼容三种常见写法：完整 /chat/completions 地址、OpenAI /responses 地址、
    /// 以及只填了 base URL（自动补 /v1/chat/completions）。
    private static func requestTarget(for settings: LLMSettings) -> (url: URL, chatCompletions: Bool)? {
        let raw = settings.resolvedVisionEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let components = URLComponents(string: raw) else { return nil }
        let path = components.path.lowercased()
        if path.contains("/chat/completions"), let url = components.url {
            return (url, true)
        }
        if path.contains("/responses"), let url = components.url {
            return (url, false)
        }
        var base = raw
        while base.hasSuffix("/") { base.removeLast() }
        if base.hasSuffix("/v1") {
            base += "/chat/completions"
        } else if !base.hasSuffix("/v1/chat/completions") {
            base += "/v1/chat/completions"
        }
        guard let url = URL(string: base) else { return nil }
        return (url, true)
    }

    private static func responseText(from data: Data, chatCompletions: Bool) throws -> String {
        if chatCompletions {
            guard
                let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = envelope["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String,
                !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                let preview = String(data: data, encoding: .utf8) ?? ""
                throw CloudVisionError.invalidResponse(String(preview.prefix(200)))
            }
            return content
        }
        let envelope = try JSONDecoder().decode(CloudVisionResponsesEnvelope.self, from: data)
        if let direct = envelope.outputText, !direct.isEmpty { return direct }
        let texts = envelope.output?.flatMap { $0.content?.compactMap(\.text) ?? [] } ?? []
        guard let text = texts.first(where: { !$0.isEmpty }) else {
            throw CloudVisionError.invalidResponse("响应里没有文本内容")
        }
        return text
    }

    // MARK: - 解析

    private static func items(from text: String) -> [DetectedItem] {
        guard let json = Self.extractJSONObject(from: text),
              let data = json.data(using: .utf8)
        else { return [] }
        let decoder = JSONDecoder()
        var raws: [RawItem] = []
        if let envelope = try? decoder.decode(Envelope.self, from: data), let items = envelope.items {
            raws = items
        } else if let array = try? decoder.decode([RawItem].self, from: data) {
            raws = array
        } else if let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = dictionary["items"] as? [[String: Any]] {
            // 有些模型会把坐标写成字符串，这里做一次宽松兜底。
            raws = items.compactMap(Self.looseItem)
        }
        return raws.compactMap(Self.item).prefix(10).map { $0 }
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = stripped.firstIndex(of: "{"), let end = stripped.lastIndex(of: "}") else { return nil }
        return String(stripped[start...end])
    }

    private static func item(_ raw: RawItem) -> DetectedItem? {
        let name = (raw.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 24 else { return nil }
        // 家具、背景不是收纳对象，模型列进来也不该出现在方案里。
        guard !Self.isIgnored(name: name) else { return nil }
        let category = ItemCategory(rawValue: raw.category ?? "") ?? Self.inferredCategory(for: name)
        var hint: ARHint?
        if let x = raw.x, let y = raw.y, x.isFinite, y.isFinite {
            let width = min(max(raw.width ?? 0.18, 0.05), 1)
            let height = min(max(raw.height ?? 0.16, 0.05), 1)
            let clampedX = min(max(x, 0), 1)
            let clampedY = min(max(y, 0), 1)
            hint = ARHint(x: clampedX, y: clampedY, width: width, height: height)
        }
        let confidence = min(max(raw.confidence ?? 0.9, 0.5), 0.99)
        let zone = (raw.zone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return DetectedItem(
            name: name,
            category: category,
            confidence: confidence,
            suggestedZone: zone.isEmpty ? category.suggestedZone : zone,
            arHint: hint
        )
    }

    private static func looseItem(_ dictionary: [String: Any]) -> RawItem? {
        func double(_ value: Any?) -> Double? {
            if let number = value as? Double { return number }
            if let number = value as? Int { return Double(number) }
            if let string = value as? String { return Double(string) }
            return nil
        }
        guard let name = dictionary["name"] as? String, !name.isEmpty else { return nil }
        return RawItem(
            name: name,
            category: dictionary["category"] as? String,
            count: dictionary["count"] as? Int,
            x: double(dictionary["x"]),
            y: double(dictionary["y"]),
            width: double(dictionary["width"]),
            height: double(dictionary["height"]),
            zone: dictionary["zone"] as? String,
            confidence: double(dictionary["confidence"])
        )
    }

    /// 模型偶尔会返回不在枚举里的类别名，这里按中文关键词兜底归类，
    /// 保证方案生成时拿到的是 App 认识的类别。
    /// 模型难免返回不在枚举里的类别名（杯子、文件资料等），这里按中文关键词兜底，
    /// 保证后面的方案生成拿到的是 App 认识的七类之一。
    private static func inferredCategory(for name: String) -> ItemCategory {
        let rules: [(keywords: [String], category: ItemCategory)] = [
            (["纸", "文件", "资料", "杂志", "试卷", "画册", "漫画", "课本", "快递单"], .books),
            (["笔", "尺", "橡皮", "便签", "胶带", "订书", "文具", "本子", "剪刀", "胶水"], .stationery),
            (["充电", "数据线", "耳机", "电脑", "手机", "平板", "键盘", "鼠标", "相机", "电池", "插排", "显示器", "音响", "手环"], .electronics),
            (["衣", "裤", "袜", "帽", "围巾", "外套", "裙", "被", "毯", "毛巾", "包"], .clothes),
            (["玩偶", "娃娃", "积木", "手办", "公仔", "摆件", "玩具", "模型"], .toys),
            (["垃圾", "废弃", "包装", "快递", "空瓶", "废纸", "果皮"], .trash),
            // 杯碗瓶罐没有独立类别，统一落到收纳工具，方案里会给它一个固定收纳位。
            (["杯", "碗", "盘", "碟", "瓶", "壶", "餐具", "刀", "叉", "勺", "化妆", "护肤", "牙刷"], .tools),
            (["书", "本"], .books)
        ]
        for rule in rules where rule.keywords.contains(where: { name.contains($0) }) {
            return rule.category
        }
        return .tools
    }

    /// 大型家具和背景不是"要收纳的东西"，模型偶尔会列进来，这里直接丢掉。
    private static let ignoredKeywords = [
        "桌子", "书桌", "椅子", "座椅", "床", "沙发", "柜", "地板", "地面", "墙壁", "墙面",
        "窗户", "窗帘", "门", "天花板", "灯", "地毯", "房间", "背景", "墙纸", "楼梯",
    ]

    private static func isIgnored(name: String) -> Bool {
        ignoredKeywords.contains(where: { name.contains($0) })
    }

    private static func jpegData(for image: UIImage) -> Data? {
        let size = image.size
        let scale = min(1, Self.maxImageEdge / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        UIGraphicsBeginImageContextWithOptions(target, true, 1)
        image.draw(in: CGRect(origin: .zero, size: target))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return (scaled ?? image).jpegData(compressionQuality: 0.7)
    }

    private static let prompt = """
    你是收纳 App「灵爪收纳」的图像识别引擎。用户拍了一张需要整理的居家或桌面照片。
    请找出画面里所有可以被收纳、归位、整理的小件物品。

    输出要求：
    1. 只输出 JSON，不要 Markdown 代码块，不要任何解释文字。
    2. 格式：{"items":[{"name":"中文物品名","category":"类别","count":数量,"x":中心横坐标,"y":中心纵坐标,"width":框宽,"height":框高,"zone":"建议放置区域"}]}
    3. category 只能从这七项里选一个：书籍、电子产品、文具、衣物、玩偶杂物、待丢弃、收纳工具。
       归类参考：杯子、碗、餐具、水瓶、化妆品 → 收纳工具；纸张、文件、资料、本子、课本 → 书籍；
       充电器、数据线、耳机、键盘、鼠标、电脑、手机、平板 → 电子产品；
       垃圾、快递包装、空瓶、废纸 → 待丢弃；实在判断不了 → 收纳工具。
    4. 不要列入：桌子、椅子、床、沙发、柜子、地板、墙壁、窗户、门、灯这类大型家具和背景，也不要列画面边缘只露一半的物体。
    5. x、y 是物品中心在画面中的位置，取值 0 到 1（左上 0,0，右下 1,1）；width、height 是物品占画面的比例，取值 0.05 到 1。
    6. 最多 10 条，按画面中显眼程度排序；同类物品可以合并成一条并给出 count。
    7. name 用简洁中文，不超过 12 个字，不要写位置描述，同类物品用同一个名字。
    8. 宁可多列也不要漏 —— 用户要靠这些物品生成收纳方案。只有画面里确实什么都没有时才返回 {"items":[]}。
    """

    private struct Envelope: Decodable {
        var items: [RawItem]?
    }

    private struct RawItem: Decodable {
        var name: String?
        var category: String?
        var count: Int?
        var x: Double?
        var y: Double?
        var width: Double?
        var height: Double?
        var zone: String?
        var confidence: Double?
    }
}

private struct CloudVisionRequest: Encodable {
    var model: String
    var input: [CloudVisionInputMessage]
}

private struct CloudVisionInputMessage: Encodable {
    var role: String
    var content: [CloudVisionInputContent]
}

private struct CloudVisionInputContent: Encodable {
    var type: String
    var text: String?
    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }
}

private struct CloudVisionResponsesEnvelope: Decodable {
    var outputText: String?
    var output: [CloudVisionOutput]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

private struct CloudVisionOutput: Decodable {
    var content: [CloudVisionContent]?
}

private struct CloudVisionContent: Decodable {
    var text: String?
}
