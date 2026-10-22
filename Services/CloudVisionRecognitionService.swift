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
/// 这条路径补充中文物品名、类别和大致位置；模型仍可能漏检或识别错误，
/// 结果需要允许用户确认和修正。
struct CloudVisionRecognitionService: Sendable {
    private let session: URLSession
    private let responseObserver: (@Sendable (String) -> Void)?

    init(session: URLSession = .shared, responseObserver: (@Sendable (String) -> Void)? = nil) {
        self.session = session
        self.responseObserver = responseObserver
    }

    /// 上传前把长边压到这个尺寸：视觉模型在这个分辨率下就够用，流量和延迟都更可控。
    private static let maxImageEdge: CGFloat = 2048
    private static let timeout: TimeInterval = 90

    func recognize(image: UIImage, settings: LLMSettings) async throws -> [DetectedItem] {
        guard settings.canRequestVision else { throw CloudVisionError.notConfigured }
        guard let imageData = Self.jpegData(for: image) else { throw CloudVisionError.invalidImage }
        let text = try await send(prompt: Self.prompt, imageData: imageData, settings: settings)
        responseObserver?(text)
        return try Self.validatedItems(from: text)
    }

    /// A visual, subjective clutter index; never derived from recognition counts.
    func assessDisorder(image: UIImage, settings: LLMSettings) async throws -> VisualDisorderAssessment {
        guard settings.canRequestVision else { throw CloudVisionError.notConfigured }
        try Task.checkCancellation()
        guard let imageData = Self.jpegData(for: image) else { throw CloudVisionError.invalidImage }
        let text = try await send(prompt: Self.disorderPrompt, imageData: imageData, settings: settings)
        try Task.checkCancellation()
        return try Self.validatedDisorder(from: text)
    }

    /// A fallible comparison, not a guarantee that every generated detail is faithful.
    func reviewPreview(source: UIImage, preview: UIImage, settings: LLMSettings) async throws -> PreviewFidelityAssessment {
        guard settings.canRequestVision else { throw CloudVisionError.notConfigured }
        try Task.checkCancellation()
        guard let sourceData = Self.jpegData(for: source), let previewData = Self.jpegData(for: preview) else {
            throw CloudVisionError.invalidImage
        }
        let text = try await send(prompt: Self.previewFidelityPrompt, imageData: sourceData, settings: settings, additionalImageData: [previewData])
        try Task.checkCancellation()
        return try Self.validatedPreviewFidelity(from: text)
    }

    static func validatedPreviewFidelity(from text: String) throws -> PreviewFidelityAssessment {
        guard let json = extractJSONObject(from: text), let data = json.data(using: .utf8),
              let assessment = try? JSONDecoder().decode(PreviewFidelityAssessment.self, from: data),
              assessment.issues.count <= 8,
              assessment.issues.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200 }),
              (assessment.verdict == .pass ? assessment.issues.isEmpty : !assessment.issues.isEmpty) else {
            throw CloudVisionError.invalidResponse("效果图保真评估缺失或结论/依据不合法")
        }
        return assessment
    }

    private static let previewFidelityPrompt = """
    你是收纳App的效果图保真检查员。对比两张图片：图片1是原始照片，图片2是建议的整理效果图。
    只检查能从两张图直接观察到的事实，不以美观或整洁作为通过依据。逐类核对物品数量、
    重复或消失、外形身份、相机视角和画幅，以及桌子、柜子、墙面等固定家具与背景。
    物品移动到新位置可以接受，但不能复制、删除、替换或凭空添加。特别注意黑笔、
    电子设备及夹板上的金属夹，以原图实际可见数量为准，不预设任何物品的数量。
    不得把原物的配件复制到新位置却在原位继续保留，也不得把多个原物或配件合并。
    相似物品也需逐实例比较，不能因归类相同就认为数量一致。若遮挡、分辨率或重绘
    导致无法核实数量或身份，结论必须是uncertain，不猜测为通过。发现明确改变返回fail。
    仅在没有发现改变且能够核实主要可见物品与固定空间时返回pass。
    只输出JSON：{"verdict":"pass","issues":[]}。verdict只能为pass/fail/uncertain。
    pass的issues必须为空；fail或uncertain的issues必须为1至8条简短中文可见事实，
    明确指出物品或无法核实的原因，不输出精确率或保真保证。
    """

    static func validatedDisorder(from text: String) throws -> VisualDisorderAssessment {
        guard let json = extractJSONObject(from: text), let data = json.data(using: .utf8),
              let assessment = try? JSONDecoder().decode(VisualDisorderAssessment.self, from: data),
              (0...100).contains(assessment.score), (0...240).contains(assessment.estimatedMinutes),
              !assessment.evidence.isEmpty, assessment.evidence.count <= 6,
              assessment.evidence.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 200 }),
              assessment.clutterRegions.count <= 12,
              assessment.clutterRegions.allSatisfy({ $0.isValid }) else {
            throw CloudVisionError.invalidResponse("视觉评估缺失或数值/区域不合法")
        }
        return assessment
    }

    private static let disorderPrompt = """
    你是收纳App的照片视觉评估器，只依据当前照片判断可见的杂乱程度。
    物品多不等于混乱：整齐排列的多本书或多件物品可以很整洁。重点看堆积、无序遮挡、
    可用台面和通行区域被占用、物品是否有序归位。不按识别物品数或类别数线性打分，
    不推测照片以外的空间。无法评估时不要编造分数，返回 {"unavailable":true}。
    只输出JSON：{"score":0,"level":"tidy","evidence":["可见事实"],"clutterRegions":[],"estimatedMinutes":0}
    score为0到100的主观视觉混乱指数，不是识别准确率。level仅tidy/light/moderate/heavy。
    evidence为1至6条简短中文可见依据；estimatedMinutes为0至240的粗略整理分钟数。
    clutterRegions最多12个真实杂乱区域，无明显区域返回空数组。每个区域格式
    {"x":0.1,"y":0.2,"width":0.2,"height":0.3,"label":"无序堆叠的纸张"}。
    坐标采用左上角原点的归一矩形，x,y>=0，width,height>0，x+width<=1，y+height<=1。
    不把整齐的物品标成杂乱点，不输出固定模板区域。
    """

    // MARK: - 网络

    private func send(prompt: String, imageData: Data, settings: LLMSettings, additionalImageData: [Data] = []) async throws -> String {
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
            let parts: [[String: Any]] = [["type": "text", "text": prompt]] + ([imageData] + additionalImageData).map { data in
                [
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(data.base64EncodedString())", "detail": "high"]
                ]
            }
            let payload: [String: Any] = [
                "model": settings.resolvedVisionModel,
                "temperature": 0.2,
                "max_tokens": 6000,
                "messages": [["role": "user", "content": parts]]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } else {
            let content = [CloudVisionInputContent(type: "input_text", text: prompt, imageURL: nil)] + ([imageData] + additionalImageData).map { data in
                CloudVisionInputContent(
                    type: "input_image",
                    text: nil,
                    imageURL: "data:image/jpeg;base64,\(data.base64EncodedString())"
                )
            }
            request.httpBody = try JSONEncoder().encode(CloudVisionRequest(
                model: settings.resolvedVisionModel,
                input: [CloudVisionInputMessage(role: "user", content: content)]
            ))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw CloudVisionError.transport(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            print("SMARTPAW_VISION_HTTP \(http.statusCode)")
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

    static func responseText(from data: Data, chatCompletions: Bool) throws -> String {
        if chatCompletions {
            guard
                let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = envelope["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String,
                !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw CloudVisionError.invalidResponse("响应里没有文本内容")
            }
            return content
        }
        let envelope = try JSONDecoder().decode(CloudVisionResponsesEnvelope.self, from: data)
        if let direct = envelope.outputText, !direct.isEmpty { return direct }
        let texts = envelope.output?.flatMap { $0.content?.compactMap(\.text) ?? [] } ?? []
        let text = texts.filter { !$0.isEmpty }.joined(separator: "\n")
        guard !text.isEmpty else {
            throw CloudVisionError.invalidResponse("响应里没有文本内容")
        }
        return text
    }

    // MARK: - 解析

    /// Empty items is a valid scene result; malformed model text is a failure.
    static func validatedItems(from text: String) throws -> [DetectedItem] {
        guard let json = extractJSONObject(from: text), let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            throw CloudVisionError.invalidResponse("没有有效的物品 JSON")
        }
        let list = (object as? [String: Any])?["items"] ?? object
        guard list is [[String: Any]] else {
            throw CloudVisionError.invalidResponse("物品列表格式不正确")
        }
        return items(from: json)
    }

    static func items(from text: String) -> [DetectedItem] {
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
        return raws.compactMap(Self.item)
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("["), stripped.hasSuffix("]") { return stripped }
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
            let width = min(max(raw.width ?? 0.18, 0.005), 1)
            let height = min(max(raw.height ?? 0.16, 0.005), 1)
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
    private static func inferredCategory(for name: String) -> ItemCategory {
        let rules: [(keywords: [String], category: ItemCategory)] = [
            (["纸", "文件", "资料", "杂志", "试卷", "画册", "漫画", "课本", "快递单"], .books),
            (["笔", "尺", "橡皮", "便签", "胶带", "订书", "文具", "本子", "剪刀", "胶水"], .stationery),
            (["充电", "数据线", "耳机", "电脑", "手机", "平板", "键盘", "鼠标", "相机", "电池", "插排", "显示器", "音响", "手环"], .electronics),
            (["衣", "裤", "袜", "帽", "围巾", "外套", "裙", "被", "毯", "毛巾", "包"], .clothes),
            (["玩偶", "娃娃", "积木", "手办", "公仔", "摆件", "玩具", "模型"], .toys),
            (["垃圾", "废弃", "包装", "快递", "空瓶", "废纸", "果皮"], .trash),
            (["药", "体温计", "血压", "创可贴", "口罩"], .health),
            (["杯", "水瓶", "水壶", "饮料", "咖啡", "茶壶"], .drinks),
            (["碗", "盘", "碟", "餐具", "刀", "叉", "勺", "锅"], .kitchen),
            (["台灯", "相框", "花瓶", "装饰"], .decor),
            (["化妆", "护肤", "牙刷"], .tools),
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
        "窗户", "窗帘", "门", "天花板", "吊灯", "吸顶灯", "地毯", "房间", "背景", "墙纸", "楼梯",
    ]

    private static func isIgnored(name: String) -> Bool {
        ignoredKeywords.contains(where: { name.contains($0) })
    }

    private static func jpegData(for image: UIImage) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0, size.width.isFinite, size.height.isFinite else { return nil }
        let scale = min(1, Self.maxImageEdge / max(size.width, size.height))
        let target = CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        UIGraphicsBeginImageContextWithOptions(target, true, 1)
        image.draw(in: CGRect(origin: .zero, size: target))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return (scaled ?? image).jpegData(compressionQuality: 0.85)
    }

    private static let prompt = """
    你是收纳 App「灵爪收纳」的图像识别引擎。用户拍了一张需要整理的居家或桌面照片。
    请找出画面里所有可以被收纳、归位、整理的小件物品。

    输出要求：
    1. 只输出 JSON，不要 Markdown 代码块，不要任何解释文字。
    2. 格式：{"items":[{"name":"中文物品名","category":"类别","count":数量,"x":中心横坐标,"y":中心纵坐标,"width":框宽,"height":框高,"zone":"建议放置区域"}]}
    3. category 只能从这十一项里选一个：书籍、电子产品、文具、衣物、玩偶杂物、待丢弃、收纳工具、厨房、饮品、健康、装饰。
       归类参考：杯子、水瓶 → 饮品；碗、餐具 → 厨房；药品、体温计 → 健康；台灯、相框 → 装饰；化妆品 → 收纳工具；纸张、文件、资料、本子、课本 → 书籍；
       充电器、数据线、耳机、键盘、鼠标、电脑、手机、平板 → 电子产品；
       垃圾、快递包装、空瓶、废纸 → 待丢弃；实在判断不了 → 收纳工具。
    4. 不要列入：桌子、椅子、床、沙发、柜子、地板、墙壁、窗户、门、吊灯这类大型家具和背景。部分遮挡但能够可靠辨认的物品仍需列出，框只覆盖可见部分；无法辨认的不要猜测。
    5. x、y 是物品中心在画面中的位置，取值 0 到 1（左上 0,0，右下 1,1）；width、height 是物品占画面的比例，取值大于 0 到 1；小物品使用实际可见大小，不要统一放大。
    6. 按物品实例逐件列出，同类物品位于不同位置也分别列出，count 固定为 1；不要把多个杯子或多本书合成一条。不要只列最显眼的前 10 件。
    7. name 用简洁中文，不超过 12 个字，不要写位置描述，同类物品用同一个名字。
    8. 只列画面中可见且能够辨认的物品，不推测画面外或收纳盒内的物品；没有可可靠辨认的目标时返回 {"items":[]}。
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

/// All required fields are decoded strictly; no fabricated fallback assessment.
struct VisualDisorderAssessment: Codable, Sendable, Equatable {
    enum Level: String, Codable, Sendable { case tidy, light, moderate, heavy }
    struct Region: Codable, Sendable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let label: String
        var isValid: Bool {
            [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width > 0 && height > 0
                && x + width <= 1 && y + height <= 1
                && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && label.count <= 100
        }
    }
    let score: Int
    let level: Level
    let evidence: [String]
    let clutterRegions: [Region]
    let estimatedMinutes: Int
}

/// A model review may fail or remain uncertain; decoding never fabricates a pass.
struct PreviewFidelityAssessment: Codable, Sendable, Equatable {
    enum Verdict: String, Codable, Sendable { case pass, fail, uncertain }
    let verdict: Verdict
    let issues: [String]
}
