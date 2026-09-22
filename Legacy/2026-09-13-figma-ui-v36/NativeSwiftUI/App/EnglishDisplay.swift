import Foundation

/// English presentation labels for the current data model.
/// Stored and recognition values remain unchanged for compatibility.
enum EnglishDisplay {
    private static var currentLanguage: AppLanguage {
        UserDefaults.standard.string(forKey: "SmartPaw.appLanguage")
            .flatMap(AppLanguage.init(rawValue:)) ?? .chinese
    }

    static func category(_ value: ItemCategory) -> String {
        guard currentLanguage == .english else { return value.rawValue }
        return switch value {
        case .books: "Books"
        case .electronics: "Electronics"
        case .stationery: "Stationery"
        case .clothes: "Clothes"
        case .toys: "Toys & Misc."
        case .trash: "To Discard"
        case .tools: "Storage Tools"
        }
    }

    static func item(_ value: String) -> String {
        guard currentLanguage == .english else { return value }
        return replace(value, with: [
            "课本": "Textbook", "平板电脑": "Tablet", "充电线": "Charging Cable",
            "马克笔": "Marker", "便签纸": "Sticky Notes", "外套": "Jacket",
            "玩偶": "Plush Toy", "空包装": "Empty Packaging", "收纳盒": "Storage Box",
            "咖啡杯": "Coffee Mug", "宠物玩具": "Pet Toy", "电视设备": "TV Device", "小夏": "Xia", "我": "Me",
            "床铺区域": "Bed Area", "衣物区域": "Clothing Area", "座椅": "Chair",
            "桌面区域": "Desk Area", "柜架收纳区": "Shelving Area", "空间家具": "Space Furniture"
        ])
    }

    static func space(_ value: String) -> String {
        guard currentLanguage == .english else { return value }
        return replace(value, with: [
            "宿舍桌面": "Dorm Desk", "床边收纳角": "Bedside Storage", "社区复刻": "Community Remix"
        ])
    }

    static func zone(_ value: String) -> String {
        guard currentLanguage == .english else { return value }
        return replace(value, with: [
            "书架 / 左侧竖放区": "Bookshelf / Left Vertical Zone",
            "桌面右上角充电区": "Upper-Right Charging Zone",
            "抽屉浅层分隔区": "Shallow Drawer Divider",
            "布筐临时折叠区": "Fabric Basket / Temporary Fold",
            "展示格 / 低频收纳区": "Display Shelf / Low Frequency",
            "垃圾袋 / 回收袋": "Trash / Recycling Bag",
            "手边工具区": "Nearby Tool Zone",
            "桌面中央": "Desk Center", "右侧抽屉 / 桌面右下": "Right Drawer / Lower Right Desk",
            "左侧书本区 / 右侧充电区": "Left Book Zone / Right Charging Zone",
            "待确认收纳区": "Unconfirmed Storage Zone", "已标记收纳区域": "Marked Storage Area",
            "重点标签": "Focus tags"
        ])
    }

    static func style(_ value: StorageStyle) -> String {
        guard currentLanguage == .english else { return value.rawValue }
        return switch value {
        case .quickReset: "Quick Reset"
        case .warmVisible: "Warm & Visible"
        case .hiddenClean: "Hidden & Clean"
        case .professional: "Professional Loop"
        }
    }

    static func duration(_ value: String) -> String {
        guard currentLanguage == .english else { return value }
        return replace(value, with: ["分钟": "min", "时长": "Duration"])
    }

    static func text(_ value: String) -> String {
        guard currentLanguage == .english else { return chineseText(value) }
        var result = value
        let replacements: [(String, String)] = [
            ("扫描失败：", "Scan failed: "), ("照片已保存，可继续开始扫描。", "Photo saved. You can continue scanning."),
            ("找不到真实照片素材：", "Could not find photo asset: "), ("空间结构已扫描，但没有识别到可归档的家具。", "The space was scanned, but no archivable furniture was recognized."),
            ("空间扫描完成，已归档 ", "Space scan complete. Archived "), (" 个家具与区域。", " furniture and zones."),
            ("请至少选择一件需要整理的物品。", "Select at least one item to organize."), ("云端 AI 已优化收纳方案。", "Cloud AI optimized the storage plan."),
            ("已生成本地方案；云端 AI 暂不可用：", "Created a local plan. Cloud AI is unavailable: "),
            ("步骤已完成，请拍摄或导入整理后的照片生成对比成果。", "Step complete. Capture or import a finished photo to create the comparison."),
            ("保存整理后照片失败：", "Could not save the finished photo: "), ("还没有可分享的完成记录。", "There is no completed record to share yet."),
            ("请先拍摄或导入完成照，再分享真实的前后对比。", "Capture or import a finished photo before sharing the real comparison."),
            ("这次成果已经分享到社区。", "This result was shared to Community."), ("已分享到社区，可被一键复刻。", "Shared to Community and ready to remix."),
            ("已复刻「", "Remixed \""), ("」的整理风格。", "\" storage style."), ("评论已发布。", "Comment posted."),
            ("AI 设置已保存。", "AI settings saved."), ("连接成功，Endpoint、API Key 与模型均可用。", "Connection succeeded. Endpoint, API key, and model are available."),
            ("当前无网络连接。", "No internet connection."), ("无法连接 Endpoint，请检查地址与服务状态。", "Unable to connect to the endpoint. Check its address and status."),
            ("连接超时，请检查 Endpoint 或网络。", "Connection timed out. Check the endpoint or network."), ("连接失败：", "Connection failed: "),
            ("连接测试失败：", "Connection test failed: "), ("日程已保存，但提醒调度失败：", "Schedule saved, but reminder scheduling failed: "),
            ("无法开启日程提醒：", "Unable to enable schedule reminders: "), ("收纳完成，已生成前后对比与成就记录。", "Storage complete. Before-and-after results and achievement records were created."),
            ("保存失败：", "Save failed: "), ("导入照片失败：", "Photo import failed: "), ("无法读取这张照片，请换一张图片重试。", "Unable to read this photo. Please try another image."),
            ("灵爪收纳", "Smart Paw"), ("灵爪", "Smart Paw"), ("浣序", "Huànxù"),
            ("考研桌面 10 分钟复原", "Exam Desk 10-Minute Reset"), ("合租卧室隐藏式收纳", "Hidden Storage for a Shared Bedroom"),
            ("手作材料可见式分类", "Visible Sorting for Craft Supplies"),
            ("桌面", "Desk"), ("书本", "Books"), ("快收", "Quick reset"), ("租房", "Rental home"),
            ("抽屉", "Drawer"), ("低成本", "Low cost"), ("手作", "Crafts"), ("标签", "Labels"),
            ("我的收纳空间", "My Storage Spaces"), ("收纳进度", "Storage Progress"),
            ("已完成", "Completed"), ("待整理", "Needs Sorting"), ("进行中", "In Progress"),
            ("暂无", "No "), ("没有", "No "), ("物品", "items"), ("项目", "items"),
            ("空间", "spaces"), ("区域", "zones"), ("次数", "times"), ("个", " "), ("件", " "),
            ("分类库", "Catalog"), ("分类", "Categories"), ("书籍", "Books"),
            ("电子产品", "Electronics"), ("文具", "Stationery"), ("衣物", "Clothes"),
            ("玩偶杂物", "Toys & Misc."), ("待丢弃", "To Discard"), ("收纳工具", "Storage Tools"),
            ("推荐", "Recommended"), ("热门", "Popular"), ("技巧", "Tips"), ("衣柜", "Closet"),
            ("低压力", "Low pressure"), ("中等", "Medium"), ("已验证", "Verified"),
            ("今天", "Today"), ("明天", "Tomorrow"), ("周六", "Saturday"), ("刚刚", "Just now"),
            ("本周", "This week"), ("本月", "This month"), ("查看全部", "View all"),
            ("一键复刻", "Remix this plan"), ("复刻", "Remix"), ("方案", "Plan"),
            ("作者", "Author"), ("风格", "Style"), ("预计耗时", "Estimated time"),
            ("用时", "Duration"), ("匹配度", "Match"), ("帮助与反馈", "Help & Feedback"),
            ("好友", "Friends"), ("设置", "Settings"), ("徽章", "Badges"), ("帖子", "Posts"),
            ("我的", "My"), ("保存", "Save"), ("已保存", "Saved"), ("取消", "Cancel"),
            ("完成", "Done"), ("编辑", "Edit"), ("删除", "Delete"), ("关闭", "Close"),
            ("返回", "Back"), ("添加", "Add"), ("清除", "Clear"), ("搜索", "Search"),
            ("评论", "Comments"), ("点赞", "Like"), ("关注", "Follow"), ("开始", "Start"),
            ("拍摄", "Capture"), ("识别", "Recognize"), ("生成", "Generate"), ("整理", "Organize"),
            ("收纳", "Storage"), ("区域", "Zone"), ("建议位置", "Suggested location"),
            ("推荐位置", "Recommended location"), ("使用建议", "Usage tips"), ("来源空间", "Source space"),
            ("智能方案", "Smart plan"), ("快速模式", "Quick mode"), ("严谨整理", "Thorough mode"),
            ("自定义", "Custom"), ("所需工具", "Tools needed"), ("整理方法", "Method"),
            ("前后对比", "Before & After"), ("存储小贴士", "Storage tips"),
            ("整洁大师", "Tidy Master"), ("整理大师", "Organization Master"),
            ("启动不拖延", "Start Without Delay"), ("十分钟复原", "Ten-Minute Reset"),
            ("秩序收藏家", "Order Collector"), ("同款复刻", "Plan Remixer"), ("前后对比", "Before & After"),
            ("整洁的浣熊", "Tidy Explorer"), ("凌乱终结者", "Clutter Finisher")
        ]
        for (source, target) in replacements { result = result.replacingOccurrences(of: source, with: target) }
        return result
    }

    private static func chineseText(_ value: String) -> String {
        let replacements: [(String, String)] = [
            ("Unable to read this photo. Please try another image.", "无法读取这张照片，请换一张图片重试。"),
            ("Photo import failed:", "导入照片失败："),
            ("Unable to read the camera frame. Please try again.", "无法读取相机画面，请再试一次。"),
            ("Unable to read the scan. Please record again.", "无法读取扫描结果，请重新录制。"),
            ("This device cannot read the camera. Import a photo from the library.", "当前设备无法读取相机，请从相册导入照片。"),
            ("Tap the red record button to complete a scan first.", "请先点击红色录像按钮完成一次扫描。"),
            ("Scan started. Move slowly to cover the space.", "已开始扫描，请缓慢移动镜头覆盖空间。"),
            ("Both multi-angle captures are ready for preview.", "两张多镜头素材已经准备好，可以进入预览。"),
            ("Save the plan or start a remix.", "请保存方案或开始复刻。"),
            ("Plan saved", "方案已保存"),
            ("Open the Community case page to view comments.", "请打开社区案例页面查看评论。"),
            ("Back to the space home.", "返回空间首页。"),
            ("This plan is complete", "这个方案已经完成"),
            ("This device does not support RoomPlan", "当前设备不支持 RoomPlan"),
            ("The space scan could not be completed.", "空间扫描未能完成。"),
            ("Please scan again.", "请重新扫描。"),
            ("Space scan failed", "空间扫描失败"),
            ("Finished photo import failed:", "导入完成照片失败：")
        ]
        return replacements.reduce(value) { result, pair in
            result.replacingOccurrences(of: pair.0, with: pair.1)
        }
    }

    private static func replace(_ value: String, with replacements: [String: String]) -> String {
        replacements.reduce(value) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    }
}

extension ItemCategory {
    var englishName: String { EnglishDisplay.category(self) }
}

extension StorageStyle {
    var englishName: String { EnglishDisplay.style(self) }
}

extension TimeBudget {
    var englishTitle: String { "\(rawValue) min" }
}

extension DetectedItem {
    var englishName: String { EnglishDisplay.item(name) }
    var englishCategory: String { category.englishName }
    var englishZone: String { EnglishDisplay.zone(suggestedZone) }
}

extension StorageSpace {
    var englishName: String { EnglishDisplay.space(name) }
    var englishSubtitle: String { EnglishDisplay.text(subtitle) }
}

extension CommunityCase {
    var englishTitle: String { EnglishDisplay.text(title) }
    var englishAuthor: String { EnglishDisplay.item(author) }
    var englishDuration: String { EnglishDisplay.duration(durationText) }
    var englishDifficulty: String { EnglishDisplay.text(difficultyText) }
    var englishTags: [String] { tags.map { EnglishDisplay.text($0) } }
}

extension ProfileBadge {
    var englishTitle: String { EnglishDisplay.text(title) }
    var englishDescription: String { EnglishDisplay.text(description) }
}

extension ScheduleItem {
    var englishTitle: String { EnglishDisplay.text(title) }
    var englishSpaceName: String { EnglishDisplay.space(spaceName) }
}
