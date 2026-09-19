import Foundation

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case books = "书籍"
    case electronics = "电子产品"
    case stationery = "文具"
    case clothes = "衣物"
    case toys = "玩偶杂物"
    case trash = "待丢弃"
    case tools = "收纳工具"

    var id: String { rawValue }

    var suggestedZone: String {
        switch self {
        case .books: "书架 / 左侧竖放区"
        case .electronics: "桌面右上角充电区"
        case .stationery: "抽屉浅层分隔区"
        case .clothes: "布筐临时折叠区"
        case .toys: "展示格 / 低频收纳区"
        case .trash: "垃圾袋 / 回收袋"
        case .tools: "手边工具区"
        }
    }
}

struct DetectedItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var category: ItemCategory
    var confidence: Double
    var suggestedZone: String
    var isSelected: Bool
    var arHint: ARHint?
    var arMask: ARMask?

    init(id: UUID = UUID(), name: String, category: ItemCategory, confidence: Double, suggestedZone: String? = nil, isSelected: Bool = true, arHint: ARHint? = nil, arMask: ARMask? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.confidence = confidence
        self.suggestedZone = suggestedZone ?? category.suggestedZone
        self.isSelected = isSelected
        self.arHint = arHint
        self.arMask = arMask
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case confidence
        case suggestedZone
        case isSelected
        case arHint
        case arMask
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ItemCategory.self, forKey: .category)
        confidence = try container.decode(Double.self, forKey: .confidence)
        suggestedZone = try container.decode(String.self, forKey: .suggestedZone)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        arHint = try container.decodeIfPresent(ARHint.self, forKey: .arHint)
        arMask = try container.decodeIfPresent(ARMask.self, forKey: .arMask)
    }
}

enum StorageStyle: String, Codable, CaseIterable, Identifiable {
    case quickReset = "快速复原"
    case warmVisible = "温暖可见"
    case hiddenClean = "隐藏清爽"
    case professional = "专业闭环"

    var id: String { rawValue }
}

enum TimeBudget: Int, Codable, CaseIterable, Identifiable {
    case five = 5
    case ten = 10
    case sixty = 60

    var id: Int { rawValue }
    var title: String { "\(rawValue) 分钟" }
}

enum StepStatus: String, Codable {
    case pending
    case active
    case done
}

struct ARHint: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let centerFallback = ARHint(x: 0.5, y: 0.5, width: 0.34, height: 0.22)
}

struct ARMaskPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct ARMask: Codable, Equatable {
    var points: [ARMaskPoint]
    var rasterWidth: Int?
    var rasterHeight: Int?
    var rasterAlpha: Data?

    init(points: [ARMaskPoint], rasterWidth: Int? = nil, rasterHeight: Int? = nil, rasterAlpha: Data? = nil) {
        self.points = points
        self.rasterWidth = rasterWidth
        self.rasterHeight = rasterHeight
        self.rasterAlpha = rasterAlpha
    }

    var isRenderable: Bool {
        hasRaster || points.count >= 3
    }

    var hasRaster: Bool {
        guard let rasterWidth, let rasterHeight, let rasterAlpha else { return false }
        return rasterWidth > 0 && rasterHeight > 0 && rasterAlpha.count == rasterWidth * rasterHeight
    }

    var rasterPixelCount: Int {
        guard let rasterAlpha, hasRaster else { return 0 }
        return rasterAlpha.reduce(0) { count, alpha in
            count + (alpha > 0 ? 1 : 0)
        }
    }

    var rasterCoverage: Double {
        guard let rasterWidth, let rasterHeight, hasRaster else { return 0 }
        let totalPixels = rasterWidth * rasterHeight
        guard totalPixels > 0 else { return 0 }
        return Double(rasterPixelCount) / Double(totalPixels)
    }

    func qualityMetrics(against reference: ARMask) -> ARMaskQualityMetrics? {
        guard let rasterWidth,
              let rasterHeight,
              let rasterAlpha,
              let referenceWidth = reference.rasterWidth,
              let referenceHeight = reference.rasterHeight,
              let referenceAlpha = reference.rasterAlpha,
              hasRaster,
              reference.hasRaster,
              rasterWidth == referenceWidth,
              rasterHeight == referenceHeight
        else { return nil }

        var predictionPixels = 0
        var referencePixels = 0
        var intersectionPixels = 0
        var unionPixels = 0

        for index in rasterAlpha.indices {
            let predicted = rasterAlpha[index] > 0
            let expected = referenceAlpha[index] > 0
            if predicted { predictionPixels += 1 }
            if expected { referencePixels += 1 }
            if predicted && expected { intersectionPixels += 1 }
            if predicted || expected { unionPixels += 1 }
        }

        return ARMaskQualityMetrics(
            width: rasterWidth,
            height: rasterHeight,
            predictionPixels: predictionPixels,
            referencePixels: referencePixels,
            intersectionPixels: intersectionPixels,
            unionPixels: unionPixels
        )
    }
}

struct ARMaskQualityMetrics: Equatable {
    var width: Int
    var height: Int
    var predictionPixels: Int
    var referencePixels: Int
    var intersectionPixels: Int
    var unionPixels: Int

    var predictionCoverage: Double {
        coverage(for: predictionPixels)
    }

    var referenceCoverage: Double {
        coverage(for: referencePixels)
    }

    var intersectionOverUnion: Double {
        guard unionPixels > 0 else { return 1 }
        return Double(intersectionPixels) / Double(unionPixels)
    }

    var diceCoefficient: Double {
        let denominator = predictionPixels + referencePixels
        guard denominator > 0 else { return 1 }
        return Double(2 * intersectionPixels) / Double(denominator)
    }

    private func coverage(for pixels: Int) -> Double {
        let totalPixels = width * height
        guard totalPixels > 0 else { return 0 }
        return Double(pixels) / Double(totalPixels)
    }
}

struct StorageStep: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var detail: String
    var zone: String
    var status: StepStatus
    var arHint: ARHint
    var arMask: ARMask?
    var itemIDs: [UUID]

    init(id: UUID = UUID(), title: String, detail: String, zone: String, status: StepStatus = .pending, arHint: ARHint, arMask: ARMask? = nil, itemIDs: [UUID]) {
        self.id = id
        self.title = title
        self.detail = detail
        self.zone = zone
        self.status = status
        self.arHint = arHint
        self.arMask = arMask
        self.itemIDs = itemIDs
    }
}

struct StoragePlan: Identifiable, Codable, Equatable {
    let id: UUID
    var style: StorageStyle
    var timeBudget: TimeBudget
    var summary: String
    var toolList: [String]
    var steps: [StorageStep]
    var completedAt: Date?

    init(id: UUID = UUID(), style: StorageStyle, timeBudget: TimeBudget, summary: String, toolList: [String], steps: [StorageStep], completedAt: Date? = nil) {
        self.id = id
        self.style = style
        self.timeBudget = timeBudget
        self.summary = summary
        self.toolList = toolList
        self.steps = steps
        self.completedAt = completedAt
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(steps.filter { $0.status == .done }.count) / Double(steps.count)
    }
}

struct StorageSpace: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var subtitle: String
    var beforeImageName: String
    var afterImageName: String
    var beforeAssetName: String?
    var afterAssetName: String?
    /// True only after the user captures or imports an after photo for this exact space.
    var hasVerifiedComparison: Bool
    /// The last time this space was refreshed by a completed organization flow.
    var lastOrganizedAt: Date?
    var detectedItems: [DetectedItem]
    var activePlan: StoragePlan?
    var completedPlans: [StoragePlan]

    init(id: UUID = UUID(), name: String, subtitle: String, beforeImageName: String, afterImageName: String, beforeAssetName: String? = nil, afterAssetName: String? = nil, hasVerifiedComparison: Bool = false, lastOrganizedAt: Date? = nil, detectedItems: [DetectedItem], activePlan: StoragePlan? = nil, completedPlans: [StoragePlan] = []) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeAssetName = beforeAssetName
        self.afterAssetName = afterAssetName
        self.hasVerifiedComparison = hasVerifiedComparison
        self.lastOrganizedAt = lastOrganizedAt
        self.detectedItems = detectedItems
        self.activePlan = activePlan
        self.completedPlans = completedPlans
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case subtitle
        case beforeImageName
        case afterImageName
        case beforeAssetName
        case afterAssetName
        case hasVerifiedComparison
        case lastOrganizedAt
        case detectedItems
        case activePlan
        case completedPlans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        beforeImageName = try container.decode(String.self, forKey: .beforeImageName)
        afterImageName = try container.decode(String.self, forKey: .afterImageName)
        beforeAssetName = try container.decodeIfPresent(String.self, forKey: .beforeAssetName)
        afterAssetName = try container.decodeIfPresent(String.self, forKey: .afterAssetName)
        hasVerifiedComparison = try container.decodeIfPresent(Bool.self, forKey: .hasVerifiedComparison) ?? false
        lastOrganizedAt = try container.decodeIfPresent(Date.self, forKey: .lastOrganizedAt)
        detectedItems = try container.decode([DetectedItem].self, forKey: .detectedItems)
        activePlan = try container.decodeIfPresent(StoragePlan.self, forKey: .activePlan)
        completedPlans = try container.decode([StoragePlan].self, forKey: .completedPlans)
    }
}

struct Achievement: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String
    var iconName: String

    init(id: UUID = UUID(), title: String, subtitle: String, iconName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
    }
}

struct CommunityCase: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var style: StorageStyle
    var likes: Int
    var tags: [String]
    var beforeImageName: String?
    var afterImageName: String?
    var beforeAssetName: String?
    var afterAssetName: String?
    var durationText: String
    var difficultyText: String
    var items: [DetectedItem]

    init(id: UUID = UUID(), title: String, author: String, style: StorageStyle, likes: Int, tags: [String], beforeImageName: String? = nil, afterImageName: String? = nil, beforeAssetName: String? = nil, afterAssetName: String? = nil, durationText: String = "10 分钟", difficultyText: String = "低压力", items: [DetectedItem] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.style = style
        self.likes = likes
        self.tags = tags
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeAssetName = beforeAssetName
        self.afterAssetName = afterAssetName
        self.durationText = durationText
        self.difficultyText = difficultyText
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case style
        case likes
        case tags
        case beforeImageName
        case afterImageName
        case beforeAssetName
        case afterAssetName
        case durationText
        case difficultyText
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        style = try container.decode(StorageStyle.self, forKey: .style)
        likes = try container.decode(Int.self, forKey: .likes)
        tags = try container.decode([String].self, forKey: .tags)
        beforeImageName = try container.decodeIfPresent(String.self, forKey: .beforeImageName)
        afterImageName = try container.decodeIfPresent(String.self, forKey: .afterImageName)
        beforeAssetName = try container.decodeIfPresent(String.self, forKey: .beforeAssetName)
        afterAssetName = try container.decodeIfPresent(String.self, forKey: .afterAssetName)
        durationText = try container.decodeIfPresent(String.self, forKey: .durationText) ?? "10 分钟"
        difficultyText = try container.decodeIfPresent(String.self, forKey: .difficultyText) ?? "低压力"
        items = try container.decode([DetectedItem].self, forKey: .items)
    }
}

struct CommunityComment: Identifiable, Codable, Equatable {
    let id: UUID
    let caseID: UUID
    var author: String
    var body: String
    var createdAt: Date
    var likes: Int

    init(id: UUID = UUID(), caseID: UUID, author: String = "我", body: String, createdAt: Date = Date(), likes: Int = 0) {
        self.id = id
        self.caseID = caseID
        self.author = author
        self.body = body
        self.createdAt = createdAt
        self.likes = likes
    }
}

struct ScheduleItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var spaceName: String
    var dueDate: Date
    var note: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, spaceName: String, dueDate: Date, note: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.spaceName = spaceName
        self.dueDate = dueDate
        self.note = note
        self.isDone = isDone
    }

    // Keeps seeded source data and previously persisted JSON compatible.
    init(id: UUID = UUID(), title: String, spaceName: String, dueText: String, note: String, isDone: Bool = false) {
        self.init(id: id, title: title, spaceName: spaceName, dueDate: Self.date(fromLegacyText: dueText), note: note, isDone: isDone)
    }

    var dueText: String {
        dueDate.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: "zh_CN"))
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, title, spaceName, dueDate, dueText, note, isDone
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        spaceName = try container.decode(String.self, forKey: .spaceName)
        if let persistedDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) {
            dueDate = persistedDate
        } else {
            dueDate = Self.date(fromLegacyText: try container.decodeIfPresent(String.self, forKey: .dueText) ?? "")
        }
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(spaceName, forKey: .spaceName)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(dueText, forKey: .dueText)
        try container.encode(note, forKey: .note)
        try container.encode(isDone, forKey: .isDone)
    }

    private static func date(fromLegacyText text: String, now: Date = Date()) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = legacyTime(in: trimmed) ?? DateComponents(hour: 9, minute: 0)
        var day = calendar.startOfDay(for: now)

        if trimmed.contains("明天") {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        } else if let weekday = legacyWeekday(in: trimmed) {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = time.hour
            components.minute = time.minute
            return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
        } else if !trimmed.contains("今天") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            for format in ["yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm", "MM-dd HH:mm", "M月d日 HH:mm"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: trimmed) { return date }
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        }

        return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: day) ?? now
    }

    private static func legacyTime(in text: String) -> DateComponents? {
        guard let match = text.range(of: #"(?:[01]?\d|2[0-3]):[0-5]\d"#, options: .regularExpression) else { return nil }
        let parts = text[match].split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return DateComponents(hour: parts[0], minute: parts[1])
    }

    private static func legacyWeekday(in text: String) -> Int? {
        let values = ["日": 1, "天": 1, "一": 2, "二": 3, "三": 4, "四": 5, "五": 6, "六": 7]
        guard let marker = text.range(of: #"(?:周|星期)[日天一二三四五六]"#, options: .regularExpression),
              let last = text[marker].last
        else { return nil }
        return values[String(last)]
    }
}

enum NotificationAuthorizationState: Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional

    var title: String {
        switch self {
        case .unknown: "正在读取通知状态"
        case .notDetermined: "尚未授权提醒"
        case .denied: "通知权限已关闭"
        case .authorized: "日程提醒已开启"
        case .provisional: "日程提醒为临时授权"
        }
    }
}

enum LLMConnectionState: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}
