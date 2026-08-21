import Foundation

enum AppSampleAssets {
    static let messyDesk = "external-messy-desk-note.png"
    static let clutteredStudy = "external-cluttered-study-pexels.jpg"
    static let clutteredRoom = "external-trash-room-imweb.jpg"
    static let all = [messyDesk, clutteredStudy, clutteredRoom]
    static let evaluationSamples = [
        messyDesk,
        clutteredStudy,
        clutteredRoom,
        "eval-editthispic-01-before.jpg",
        "eval-editthispic-02-before.jpg",
        "eval-editthispic-03-before.jpg"
    ]

    static func replacingLegacyVideoAsset(_ name: String?) -> String? {
        guard let name else { return nil }
        guard name.hasPrefix("SmartPawVideo") else { return name }
        return name.contains("After") || name.contains("Plan") || name.contains("Profile")
            ? clutteredStudy
            : messyDesk
    }
}

enum DemoData {
    static let detectedItems: [DetectedItem] = [
        DetectedItem(name: "课本", category: .books, confidence: 0.93),
        DetectedItem(name: "平板电脑", category: .electronics, confidence: 0.89),
        DetectedItem(name: "充电线", category: .electronics, confidence: 0.86),
        DetectedItem(name: "马克笔", category: .stationery, confidence: 0.91),
        DetectedItem(name: "便签纸", category: .stationery, confidence: 0.84),
        DetectedItem(name: "外套", category: .clothes, confidence: 0.78),
        DetectedItem(name: "玩偶", category: .toys, confidence: 0.81),
        DetectedItem(name: "空包装", category: .trash, confidence: 0.96)
    ]

    static let completedPlan = StoragePlan(
        style: .quickReset,
        timeBudget: .ten,
        summary: "宿舍桌面已按分区流程完成一次整理，保留高频物品，迁移低频杂物。",
        toolList: ["垃圾袋", "分隔收纳盒", "标签贴"],
        steps: [
            StorageStep(title: "清理垃圾，保留所需物品", detail: "先把空包装和无效杂物拿走，只留下今天会用到的书本、设备和文具。", zone: "桌面中央", status: .done, arHint: ARHint(x: 0.28, y: 0.62, width: 0.28, height: 0.20), itemIDs: detectedItems.filter { $0.category == .trash }.map(\.id)),
            StorageStep(title: "取出收纳盒 1", detail: "把文具和零散线材放入浅层分隔盒，减少桌面散点。", zone: "右侧抽屉 / 桌面右下", status: .done, arHint: ARHint(x: 0.62, y: 0.58, width: 0.26, height: 0.22), itemIDs: detectedItems.filter { $0.category == .stationery || $0.category == .electronics }.map(\.id)),
            StorageStep(title: "剩余物品归类排列", detail: "书本竖放，常用设备靠近插座，低频装饰移到展示格。", zone: "左侧书本区 / 右侧充电区", status: .done, arHint: ARHint(x: 0.46, y: 0.36, width: 0.48, height: 0.24), itemIDs: detectedItems.map(\.id))
        ],
        completedAt: Date(timeIntervalSinceNow: -3600)
    )

    static let spaces: [StorageSpace] = [
        StorageSpace(
            name: "宿舍桌面",
            subtitle: "复习、手作、充电都挤在同一张桌子上",
            beforeImageName: "demo-before",
            afterImageName: "demo-after",
            beforeAssetName: AppSampleAssets.messyDesk,
            afterAssetName: AppSampleAssets.clutteredStudy,
            detectedItems: detectedItems
            ,
            completedPlans: [completedPlan]
        ),
        StorageSpace(
            name: "床边收纳角",
            subtitle: "低频物品堆叠，缺少分类入口",
            beforeImageName: "demo-corner",
            afterImageName: "demo-after",
            beforeAssetName: AppSampleAssets.clutteredRoom,
            afterAssetName: AppSampleAssets.clutteredStudy,
            detectedItems: Array(detectedItems.prefix(5))
        )
    ]

    static let achievements: [Achievement] = [
        Achievement(title: "启动不拖延", subtitle: "完成第一次扫描", iconName: "camera.viewfinder"),
        Achievement(title: "十分钟复原", subtitle: "完成 10 分钟微任务", iconName: "timer"),
        Achievement(title: "秩序收藏家", subtitle: "建立 5 个物品标签", iconName: "tag"),
        Achievement(title: "同款复刻", subtitle: "收藏社区方案", iconName: "square.on.square"),
        Achievement(title: "前后对比", subtitle: "沉淀可展示成果", iconName: "photo.on.rectangle.angled")
    ]

    static let communityCases: [CommunityCase] = [
        CommunityCase(title: "考研桌面 10 分钟复原", author: "小夏", style: .quickReset, likes: 268, tags: ["桌面", "书本", "快收"], beforeAssetName: AppSampleAssets.messyDesk, afterAssetName: AppSampleAssets.clutteredStudy, durationText: "10 分钟", difficultyText: "低压力", items: Array(detectedItems.prefix(4))),
        CommunityCase(title: "合租卧室隐藏式收纳", author: "Momo", style: .hiddenClean, likes: 421, tags: ["租房", "抽屉", "低成本"], beforeAssetName: AppSampleAssets.clutteredRoom, afterAssetName: AppSampleAssets.clutteredStudy, durationText: "30 分钟", difficultyText: "中等", items: Array(detectedItems.filter { $0.category != .trash }.prefix(5))),
        CommunityCase(title: "手作材料可见式分类", author: "Lina", style: .warmVisible, likes: 179, tags: ["文具", "手作", "标签"], beforeAssetName: AppSampleAssets.clutteredStudy, afterAssetName: AppSampleAssets.messyDesk, durationText: "15 分钟", difficultyText: "低压力", items: detectedItems.filter { $0.category == .stationery || $0.category == .tools })
    ]

    static let scheduleItems: [ScheduleItem] = [
        ScheduleItem(title: "宿舍桌面复盘", spaceName: "宿舍桌面", dueText: "今天 20:30", note: "拍完成照后检查充电区是否保持清爽"),
        ScheduleItem(title: "床边收纳角二次整理", spaceName: "床边收纳角", dueText: "明天 12:20", note: "把低频物品迁移到透明盒"),
        ScheduleItem(title: "周末方案回收", spaceName: "社区复刻", dueText: "周六 10:00", note: "从收藏案例里选一个同款方案")
    ]

    static var snapshot: AppStateSnapshot {
        AppStateSnapshot(spaces: spaces, achievements: achievements, communityCases: communityCases, scheduleItems: scheduleItems)
    }
}
