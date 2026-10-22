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
            lastOrganizedAt: Date(timeIntervalSinceNow: -3600),
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
            lastOrganizedAt: Date(timeIntervalSinceNow: -26 * 24 * 60 * 60),
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
        AppStateSnapshot(spaces: spaces, achievements: achievements, communityCases: communityCases, communityComments: [:], scheduleItems: scheduleItems)
    }
}

enum PresentationData {
    private static func identifier(_ family: Int, _ index: Int) -> UUID {
        UUID(uuidString: String(format: "ED000000-%04X-4000-8000-%012X", family, index))!
    }

    private static func items(_ family: Int, _ entries: [(String, ItemCategory, String)]) -> [DetectedItem] {
        entries.enumerated().map { index, entry in
            DetectedItem(id: identifier(family, index + 1), name: entry.0, category: entry.1,
                         confidence: 0.96, suggestedZone: entry.2)
        }
    }

    static func snapshot(llmSettings: LLMSettings = .default, now: Date = Date()) -> AppStateSnapshot {
        let bedroomItems = items(1, [
            ("活着", .books, "小说"), ("傲慢与偏见", .books, "小说"), ("简·爱", .books, "小说"),
            ("设计心理学", .books, "学习"), ("设计方法与策略", .books, "学习"), ("设计中的设计", .books, "学习"),
            ("沉思录", .books, "哲学"), ("查拉图斯特拉", .books, "哲学"), ("理想国", .books, "哲学"),
            ("白色衬衫", .clothes, "日常上衣"), ("蓝色衬衫", .clothes, "日常上衣"), ("条纹T恤", .clothes, "日常上衣"),
            ("针织开衫", .clothes, "换季衣物"), ("羊毛围巾", .clothes, "换季衣物"), ("棉麻长裙", .clothes, "换季衣物"),
            ("牛仔裤", .clothes, "折叠下装"), ("运动长裤", .clothes, "折叠下装"), ("家居短裤", .clothes, "折叠下装"),
            ("体温计", .health, "床头药箱"), ("创可贴", .health, "床头药箱"), ("维生素", .health, "床头药箱"),
            ("床头相框", .decor, "床头展示"), ("小型花瓶", .decor, "床头展示"), ("香薰摆件", .decor, "床头展示")
        ])
        let kitchenItems = items(2, [
            ("陶瓷餐盘", .kitchen, "餐具柜"), ("汤碗", .kitchen, "餐具柜"), ("玻璃保鲜盒", .kitchen, "保鲜收纳"),
            ("木质砧板", .kitchen, "料理区"), ("硅胶锅铲", .kitchen, "料理区"), ("不锈钢汤勺", .kitchen, "料理区"),
            ("马克杯", .drinks, "杯具区"), ("冷水壶", .drinks, "杯具区"), ("花草茶罐", .drinks, "饮品区")
        ])
        let livingItems = items(3, [
            ("平板电脑", .tools, "充电区"), ("蓝牙耳机", .tools, "充电区"), ("手机充电器", .tools, "充电区"),
            ("USB-C数据线", .tools, "线材收纳"), ("移动电源", .tools, "线材收纳"), ("电视遥控器", .tools, "茶几抽屉"),
            ("黑色签字笔", .tools, "文具盒"), ("荧光笔", .tools, "文具盒"), ("便签纸", .tools, "文具盒"),
            ("剪刀", .tools, "文具盒"), ("手账本", .tools, "手账区"),
            ("拼图", .toys, "休闲收纳"), ("积木", .toys, "休闲收纳"), ("毛绒玩偶", .toys, "休闲收纳"),
            ("桌面游戏卡牌", .toys, "休闲收纳"), ("木质陀螺", .toys, "休闲收纳"),
            ("浅口收纳盒", .tools, "收纳用品"), ("透明分隔盒", .tools, "收纳用品"), ("理线夹", .tools, "收纳用品"),
            ("标签贴", .tools, "收纳用品"), ("折叠收纳篮", .tools, "收纳用品"), ("清洁刷", .tools, "清洁工具"),
            ("陶瓷小摆件", .decor, "茶几展示"), ("旅行相框", .decor, "茶几展示"), ("绿植花盆", .decor, "茶几展示"),
            ("玻璃水杯", .drinks, "茶水区"), ("咖啡杯", .drinks, "茶水区"), ("保温杯", .drinks, "茶水区"),
            ("小王子", .books, "小说"), ("室内收纳指南", .books, "学习"), ("幸福之路", .books, "哲学")
        ])

        func plan(_ family: Int, title: String, items: [DetectedItem], tasks: [(String, String)], done: Int,
                  paused: Bool = false, completedAt: Date? = nil, timeBudget: TimeBudget = .ten) -> StoragePlan {
            StoragePlan(id: identifier(family, 1), style: .quickReset, timeBudget: timeBudget, summary: title,
                        toolList: ["分隔收纳盒", "标签贴"], steps: tasks.enumerated().map { index, task in
                let zoneItems = items.filter { $0.suggestedZone == task.1 }
                return StorageStep(id: identifier(family, index + 2), title: task.0,
                                   detail: "把\(task.1)中的物品集中检查，保留常用物品，整理后放回固定位置。",
                                   zone: task.1, status: index < done ? .done : index == done ? .active : .pending,
                                   itemIDs: (zoneItems.isEmpty ? Array(items.prefix(3)) : zoneItems).map(\.id))
            }, isPaused: paused, completedAt: completedAt)
        }

        let bedroomTasks = [
            ("清空床边临时堆放", "床头展示"), ("集中需要整理的衣物", "日常上衣"), ("检查换季衣物", "换季衣物"),
            ("擦拭书架和床头柜", "小说"), ("整理日常上衣", "日常上衣"), ("折好家居衣物", "折叠下装"),
            ("收齐围巾与开衫", "换季衣物"), ("按阅读习惯竖放书籍", "小说"), ("集中学习用书", "学习"),
            ("建立哲学书籍分组", "哲学"), ("检查药品有效期", "床头药箱"), ("归放健康用品", "床头药箱"),
            ("摆回床头相框", "床头展示"), ("整理展示小物", "床头展示"), ("给换季收纳贴标签", "换季衣物"),
            ("为常穿上衣留出取用位", "日常上衣"), ("整理下装叠放区", "折叠下装"), ("检查书架取用空间", "小说"),
            ("收起多余包装", "床头展示"), ("完成卧室整理检查", "床头展示")
        ]
        let kitchenTasks = [("清空料理台", "料理区"), ("餐盘和碗按频率归位", "餐具柜"), ("整理保鲜盒", "保鲜收纳"),
                            ("归放杯具和水壶", "杯具区"), ("整理饮品与最后检查", "饮品区")]
        let livingTasks = [("清理茶几表面", "茶几展示"), ("分类电子设备与线材", "线材收纳"), ("整理文具与手账", "文具盒"),
                           ("玩具和卡牌分类入盒", "休闲收纳"), ("集中茶水用品", "茶水区"), ("摆回书籍与装饰", "茶几展示")]
        let day: TimeInterval = 86_400
        let bedroom = StorageSpace(id: identifier(10, 1), name: "床", subtitle: "卧室衣物、书籍与床头小物",
            beforeImageName: "", afterImageName: "", beforeAssetName: "FigmaProfilePlanCloset", afterAssetName: "FigmaProfilePlanCloset",
            lastOrganizedAt: now.addingTimeInterval(-2 * day), detectedItems: bedroomItems,
            activePlan: plan(20, title: "迷你公寓衣柜", items: bedroomItems, tasks: bedroomTasks, done: 7),
            completedPlans: [plan(30, title: "床头阅读角整理", items: bedroomItems, tasks: Array(bedroomTasks.prefix(3)), done: 3, completedAt: now.addingTimeInterval(-2 * day))])
        let kitchen = StorageSpace(id: identifier(10, 2), name: "厨房", subtitle: "料理台、杯具与餐具收纳",
            beforeImageName: "", afterImageName: "", beforeAssetName: "FigmaProfilePlanCabinet", afterAssetName: "FigmaProfilePlanCabinet",
            lastOrganizedAt: now.addingTimeInterval(-30 * day), detectedItems: kitchenItems,
            activePlan: plan(21, title: "5 分钟厨房重置", items: kitchenItems, tasks: kitchenTasks, done: 3, paused: true, timeBudget: .five),
            completedPlans: [plan(31, title: "餐具室深度清洁", items: kitchenItems, tasks: kitchenTasks, done: kitchenTasks.count, completedAt: now.addingTimeInterval(-30 * day))])
        let living = StorageSpace(id: identifier(10, 3), name: "茶几", subtitle: "客厅高频物品与休闲用品",
            beforeImageName: "", afterImageName: "", beforeAssetName: "FigmaProfilePlanLiving", afterAssetName: "FigmaProfilePlanLiving",
            lastOrganizedAt: now.addingTimeInterval(-15 * day), detectedItems: livingItems,
            activePlan: plan(22, title: "茶几轻量收纳", items: livingItems, tasks: livingTasks, done: 2),
            completedPlans: [plan(32, title: "客厅阅读角焕新", items: livingItems, tasks: Array(livingTasks.prefix(3)), done: 3, completedAt: now.addingTimeInterval(-15 * day))])
        let cases = [
            CommunityCase(id: identifier(40, 1), title: "小户型衣柜分类收纳", author: "Momo", style: .hiddenClean, likes: 42,
                          tags: ["卧室", "衣物", "换季"], beforeAssetName: "FigmaProfilePlanCloset", durationText: "10 分钟", items: Array(bedroomItems.filter { $0.category == .clothes }.prefix(4))),
            CommunityCase(id: identifier(40, 2), title: "厨房台面轻量重置", author: "小夏", style: .quickReset, likes: 36,
                          tags: ["厨房", "餐具", "轻量整理"], beforeAssetName: "FigmaProfilePlanCabinet", durationText: "5 分钟", items: Array(kitchenItems.prefix(4))),
            CommunityCase(id: identifier(40, 3), title: "茶几物品分区归位", author: "Lina", style: .warmVisible, likes: 28,
                          tags: ["客厅", "茶几", "分区"], beforeAssetName: "FigmaProfilePlanLiving", durationText: "10 分钟", items: Array(livingItems.prefix(5))),
            CommunityCase(id: identifier(40, 4), title: "阅读书架三类分组", author: "Sarah Chen", style: .warmVisible, likes: 19,
                          tags: ["书籍", "阅读", "学习"], beforeAssetName: "FigmaProfilePlanCloset", durationText: "10 分钟", items: Array(bedroomItems.prefix(9)))
        ]
        return AppStateSnapshot(spaces: [bedroom, kitchen, living], achievements: [], communityCases: cases,
            scheduleItems: [ScheduleItem(id: identifier(50, 1), title: "周末客厅重置", spaceName: "茶几",
                                         dueDate: now.addingTimeInterval(2 * day), note: "整理阅读角、检查线材收纳和茶水区。")],
            llmSettings: llmSettings, favoriteCommunityCaseIDs: Set(cases.map(\.id)),
            followedCommunityAuthors: ["Momo", "小夏", "Lina"])
    }
}
