import Foundation
import UIKit
import UserNotifications

private enum ChatError: LocalizedError {
    case notConfigured
    case httpFailure
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置可用的 AI API，请先在设置中保存 Endpoint、API Key 和模型。"
        case .httpFailure: return "AI 服务请求失败，请检查 API Key、网络或 Endpoint。"
        case .invalidResponse: return "AI 返回内容无法解析，请检查模型和接口格式。"
        }
    }
}

enum AppTab: Hashable {
    case space
    case catalog
    case capture
    case community
    case profile
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var language: AppLanguage
    @Published private(set) var hasSelectedLanguage: Bool
    @Published private(set) var spaces: [StorageSpace]
    @Published private(set) var achievements: [Achievement]
    @Published private(set) var communityCases: [CommunityCase]
    @Published private(set) var communityComments: [UUID: [CommunityComment]]
    @Published private(set) var likedCommunityCaseIDs: Set<UUID>
    @Published private(set) var favoriteCommunityCaseIDs: Set<UUID>
    @Published private(set) var followedCommunityAuthors: Set<String>
    @Published private(set) var scheduleItems: [ScheduleItem]
    @Published var selectedTab: AppTab = .space
    @Published var selectedSpaceID: UUID?
    @Published var scannedItems: [DetectedItem] = []
    @Published var capturedImage: UIImage?
    @Published var selectedStyle: StorageStyle = .quickReset
    @Published var selectedTimeBudget: TimeBudget = .ten
    @Published var planningGoal = ""
    @Published var focusZone = ""
    @Published var selectedPlanningTags: Set<String> = []
    @Published var recommendationMode: RecommendationMode = .balanced
    @Published var referenceImage: UIImage?
    @Published var selectedExecutionZones: Set<String> = []
    @Published var latestUnlockedAchievement: Achievement?
    @Published var llmSettings: LLMSettings
    @Published private(set) var llmConnectionState: LLMConnectionState = .idle
    @Published private(set) var notificationAuthorizationState: NotificationAuthorizationState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var isPlanning = false
    @Published private(set) var message: String?

    let dependencies: AppDependencies

    private static let communityLikesKey = "SmartPaw.community.likedCaseIDs"
    private static let communityFavoritesKey = "SmartPaw.community.favoriteCaseIDs"
    private static let communityFollowsKey = "SmartPaw.community.followedAuthors"
    private static let languageKey = "SmartPaw.appLanguage"
    private var activeScanID: UUID?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let storedLanguage = UserDefaults.standard.string(forKey: Self.languageKey)
            .flatMap(AppLanguage.init(rawValue:))
        // New installs start in Chinese so the first-run picker is readable
        // before the user makes a language choice.
        language = storedLanguage ?? .chinese
        hasSelectedLanguage = storedLanguage != nil
        let snapshot: AppStateSnapshot
        let loadErrorMessage: String?
        do {
            snapshot = try dependencies.storageStore.loadState() ?? DemoData.snapshot
            loadErrorMessage = nil
        } catch {
            snapshot = DemoData.snapshot
            loadErrorMessage = "本地数据读取失败，已进入恢复模式；原文件未被删除。\(error.localizedDescription)"
        }
        let persistedSpaces = snapshot.spaces.isEmpty ? DemoData.spaces : snapshot.spaces
        spaces = persistedSpaces.map { space in
            var sanitized = space
            if space.beforeAssetName?.hasPrefix("SmartPawVideo") == true {
                sanitized.beforeImageName = ""
            }
            if space.afterAssetName?.hasPrefix("SmartPawVideo") == true {
                sanitized.afterImageName = ""
            }
            sanitized.beforeAssetName = AppSampleAssets.replacingLegacyVideoAsset(space.beforeAssetName)
            sanitized.afterAssetName = AppSampleAssets.replacingLegacyVideoAsset(space.afterAssetName)
            return sanitized
        }
        achievements = snapshot.achievements
        communityCases = snapshot.communityCases.map { item in
            var sanitized = item
            if item.beforeAssetName?.hasPrefix("SmartPawVideo") == true {
                sanitized.beforeImageName = nil
            }
            if item.afterAssetName?.hasPrefix("SmartPawVideo") == true {
                sanitized.afterImageName = nil
            }
            sanitized.beforeAssetName = AppSampleAssets.replacingLegacyVideoAsset(item.beforeAssetName)
            sanitized.afterAssetName = AppSampleAssets.replacingLegacyVideoAsset(item.afterAssetName)
            return sanitized
        }
        communityComments = snapshot.communityComments
        scheduleItems = snapshot.scheduleItems.isEmpty ? DemoData.scheduleItems : snapshot.scheduleItems
        var restoredLLMSettings = snapshot.llmSettings
        let legacyAPIKey = restoredLLMSettings.apiKey
        let storedAPIKey = dependencies.credentialStore.loadAPIKey()
        restoredLLMSettings.apiKey = storedAPIKey ?? legacyAPIKey
        llmSettings = restoredLLMSettings
        let credentialMigrationFailed = storedAPIKey == nil
            && !legacyAPIKey.isEmpty
            && !dependencies.credentialStore.saveAPIKey(legacyAPIKey)
        // 社区互动状态原本存在 UserDefaults，这里并入快照后读快照；旧数据迁移一次，避免用户已点的赞丢掉。
        likedCommunityCaseIDs = snapshot.likedCommunityCaseIDs
        favoriteCommunityCaseIDs = snapshot.favoriteCommunityCaseIDs
        followedCommunityAuthors = snapshot.followedCommunityAuthors
        Self.migrateLegacyCommunityReactionsIfNeeded(
            liked: &likedCommunityCaseIDs,
            favorited: &favoriteCommunityCaseIDs,
            followed: &followedCommunityAuthors
        )
        selectedSpaceID = spaces.first?.id
        selectedExecutionZones = Set(spaces.first?.activePlan?.steps.map(\.zone) ?? [])
        message = credentialMigrationFailed
            ? "旧版 API Key 无法迁移到系统钥匙串，原数据文件已保留。"
            : loadErrorMessage
        #if DEBUG
        message = nil
        #endif
        #if DEBUG
        if let screenshotTab = CommandLine.arguments.drop { $0 != "-SmartPawScreenshotTab" }.dropFirst().first,
           let tab = Self.screenshotTab(named: screenshotTab) {
            selectedTab = tab
            message = nil
        }
        if CommandLine.arguments.contains("-SmartPawAutoCaptureCamera")
            || CommandLine.arguments.contains("-SmartPawAutoCaptureSample") {
            selectedTab = .capture
            message = nil
        }
        if CommandLine.arguments.contains("-SmartPawShowCommunity")
            || CommandLine.arguments.contains("-SmartPawShowCommunityDetail")
            || CommandLine.arguments.contains("-SmartPawShowCommunityComments")
            || CommandLine.arguments.contains("-SmartPawShowCommunityPlan") {
            selectedTab = .community
            message = nil
        }
        if CommandLine.arguments.contains("-SmartPawShowProfile")
            || CommandLine.arguments.contains("-SmartPawShowProfilePlans")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadges")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadgeDetail")
            || CommandLine.arguments.contains("-SmartPawShowProfileLockedBadgeDetail")
            || CommandLine.arguments.contains("-SmartPawShowProfileSchedule") {
            selectedTab = .profile
            message = nil
        }
        #endif
        Task { [weak self] in
            await self?.refreshNotificationAuthorizationState()
            await self?.reconcileScheduleNotifications()
        }
    }

    #if DEBUG
    private static func screenshotTab(named name: String) -> AppTab? {
        switch name.lowercased() {
        case "space": .space
        case "catalog": .catalog
        case "capture": .capture
        case "community": .community
        case "profile": .profile
        default: nil
        }
    }
    #endif

    var selectedSpace: StorageSpace {
        spaces.first(where: { $0.id == selectedSpaceID }) ?? spaces[0]
    }

    var activePlan: StoragePlan? {
        selectedSpace.activePlan
    }

    var catalogItems: [DetectedItem] {
        spaces.flatMap(\.detectedItems)
    }

    var completedCount: Int {
        spaces.flatMap(\.completedPlans).count
    }

    var selectedSpaceCompletedCount: Int {
        selectedSpace.completedPlans.count
    }

    var completedPlans: [StoragePlan] {
        spaces.flatMap(\.completedPlans)
    }

    var latestCompletedPlan: StoragePlan? {
        spaces.flatMap(\.completedPlans).sorted { lhs, rhs in
            (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
        }.first
    }

    var planningTagOptions: [String] {
        Array(Set(scannedItems.isEmpty ? selectedSpace.detectedItems.map(\.category.rawValue) : scannedItems.map(\.category.rawValue))).sorted()
    }

    var executionZoneOptions: [String] {
        guard let activePlan else { return [] }
        return Array(Set(activePlan.steps.map(\.zone))).sorted()
    }

    func selectSpace(_ id: UUID) {
        guard spaces.contains(where: { $0.id == id }) else { return }
        selectedSpaceID = id
        scannedItems = []
        capturedImage = nil
        referenceImage = nil
        selectedExecutionZones = Set(spaces.first(where: { $0.id == id })?.activePlan?.steps.map(\.zone) ?? [])
    }

    func addSpace(name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let space = StorageSpace(
            name: trimmed,
            subtitle: "等待首次扫描",
            beforeImageName: "",
            afterImageName: "",
            detectedItems: []
        )
        spaces.append(space)
        selectedSpaceID = space.id
        persist()
        return space.id
    }

    func renameSpace(_ id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = spaces.firstIndex(where: { $0.id == id }) else { return }
        spaces[index].name = trimmed
        persist()
    }

    func deleteSpace(_ id: UUID) {
        guard spaces.count > 1, let index = spaces.firstIndex(where: { $0.id == id }) else {
            message = "至少保留一个空间。"
            return
        }
        spaces.remove(at: index)
        if selectedSpaceID == id { selectSpace(spaces[0].id) }
        persist()
    }

    func replaceScannedItems(_ items: [DetectedItem]) {
        scannedItems = items
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else { return }
        spaces[index].detectedItems = items
        persist()
    }

    func scanImage(_ image: UIImage) async {
        let scanID = UUID()
        activeScanID = scanID
        capturedImage = image
        isScanning = true
        defer {
            if activeScanID == scanID {
                isScanning = false
            }
        }
        do {
            let results = try await dependencies.scanService.scanImage(image)
            guard activeScanID == scanID else { return }
            scannedItems = results
            if let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) {
                spaces[index].detectedItems = scannedItems
                spaces[index].beforeImageName = try saveImage(image, prefix: "before")
                persist()
            }
        } catch {
            guard activeScanID == scanID else { return }
            scannedItems = []
            message = "扫描失败：\(error.localizedDescription)"
        }
    }

    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        message = "照片已保存，可继续开始扫描。"
    }

    /// Merges complementary views of the same space before the user confirms the result.
    func scanImages(_ images: [UIImage], accumulate: Bool = false) async {
        guard let primaryImage = images.first else { return }
        let scanID = UUID()
        activeScanID = scanID
        capturedImage = primaryImage
        isScanning = true
        defer {
            if activeScanID == scanID {
                isScanning = false
            }
        }

        do {
            var mergedItems: [DetectedItem] = []
            for image in images {
                let results = try await dependencies.scanService.scanImage(image)
                guard activeScanID == scanID else { return }
                for item in results {
                    if let index = mergedItems.firstIndex(where: {
                        $0.name == item.name && $0.category == item.category
                    }) {
                        mergedItems[index].confidence = max(mergedItems[index].confidence, item.confidence)
                    } else {
                        mergedItems.append(item)
                    }
                }
            }

            // 连拍时每张都要并入结果：直接替换会让前面几张白拍。
            if accumulate {
                var base = scannedItems
                for item in mergedItems {
                    if let index = base.firstIndex(where: {
                        $0.name == item.name && $0.category == item.category
                    }) {
                        base[index].confidence = max(base[index].confidence, item.confidence)
                    } else {
                        base.append(item)
                    }
                }
                scannedItems = base
            } else {
                scannedItems = mergedItems
            }
            if let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) {
                spaces[index].detectedItems = scannedItems
                spaces[index].beforeImageName = try saveImage(primaryImage, prefix: "before")
                persist()
            }
        } catch {
            guard activeScanID == scanID else { return }
            scannedItems = []
            message = "扫描失败：\(error.localizedDescription)"
        }
    }

    func scanBundledSample(assetName: String) async {
        guard let image = UIImage(named: assetName) else {
            message = "找不到真实照片素材：\(assetName)。"
            return
        }
        await scanImage(image)
    }

    func importRoomPlanObjects(_ categoryNames: [String]) {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID })
        else { return }
        let imported = categoryNames.map(Self.detectedItemFromRoomCategory)
        guard !imported.isEmpty else {
            message = "空间结构已扫描，但没有识别到可归档的家具。"
            return
        }
        spaces[spaceIndex].detectedItems.append(contentsOf: imported)
        scannedItems = imported
        persist()
        message = "空间扫描完成，已归档 \(imported.count) 个家具与区域。"
    }

    func toggleScannedItem(_ itemID: UUID) {
        guard let index = scannedItems.firstIndex(where: { $0.id == itemID }) else { return }
        scannedItems[index].isSelected.toggle()
    }

    func updateScannedItem(_ item: DetectedItem) {
        guard let index = scannedItems.firstIndex(where: { $0.id == item.id }) else { return }
        scannedItems[index] = item
        if let selectedSpaceID, let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }) {
            if let itemIndex = spaces[spaceIndex].detectedItems.firstIndex(where: { $0.id == item.id }) {
                spaces[spaceIndex].detectedItems[itemIndex] = item
            }
            persist()
        }
    }

    func togglePlanningTag(_ tag: String) {
        if selectedPlanningTags.contains(tag) {
            selectedPlanningTags.remove(tag)
        } else {
            selectedPlanningTags.insert(tag)
        }
    }

    func setReferenceImage(_ image: UIImage) {
        referenceImage = image
    }

    func toggleExecutionZone(_ zone: String) {
        if selectedExecutionZones.contains(zone) {
            selectedExecutionZones.remove(zone)
        } else {
            selectedExecutionZones.insert(zone)
        }
    }

    func selectAllExecutionZones() {
        selectedExecutionZones = Set(executionZoneOptions)
    }

    func addManualItem(name: String, category: ItemCategory, forScan: Bool = false) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let selectedSpaceID,
              let index = spaces.firstIndex(where: { $0.id == selectedSpaceID })
        else { return }

        let item = DetectedItem(name: trimmedName, category: category, confidence: 1)
        spaces[index].detectedItems.insert(item, at: 0)
        if forScan {
            scannedItems.insert(item, at: 0)
        }
        message = "已添加「\(trimmedName)」到 \(spaces[index].name)。"
        persist()
    }

    func removeCatalogItem(_ itemID: UUID) {
        for index in spaces.indices {
            spaces[index].detectedItems.removeAll { $0.id == itemID }
            spaces[index].activePlan = removingItemReference(itemID, from: spaces[index].activePlan)
            spaces[index].completedPlans = spaces[index].completedPlans.compactMap { removingItemReference(itemID, from: $0) }
        }
        scannedItems.removeAll { $0.id == itemID }
        persist()
    }

    func updateCatalogItem(_ item: DetectedItem) {
        for spaceIndex in spaces.indices {
            guard let itemIndex = spaces[spaceIndex].detectedItems.firstIndex(where: { $0.id == item.id }) else { continue }
            spaces[spaceIndex].detectedItems[itemIndex] = item
        }
        if let scannedIndex = scannedItems.firstIndex(where: { $0.id == item.id }) {
            scannedItems[scannedIndex] = item
        }
        persist()
    }

    func makePlanFromScan(navigateToSpace: Bool = true) {
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else { return }
        let currentSpace = spaces[index]
        let selectedItems = scannedItems.isEmpty ? currentSpace.detectedItems : scannedItems
        guard selectedItems.contains(where: \.isSelected) else {
            message = "请至少选择一件需要整理的物品。"
            return
        }
        let plan = dependencies.planningService.makePlan(
            for: currentSpace,
            selectedItems: selectedItems,
            style: selectedStyle,
            timeBudget: selectedTimeBudget,
            goal: enrichedPlanningGoal,
            focusZone: enrichedFocusZone
        )
        spaces[index].activePlan = plan
        spaces[index].detectedItems = selectedItems
        selectedExecutionZones = Set(plan.steps.map(\.zone))
        if navigateToSpace {
            selectedTab = .space
        }
        persist()
    }

    func makePlanFromScanUsingCloudIfAvailable(navigateToSpace: Bool = true) async {
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else { return }
        let currentSpace = spaces[index]
        let selectedItems = scannedItems.isEmpty ? currentSpace.detectedItems : scannedItems
        guard selectedItems.contains(where: \.isSelected) else {
            message = "请至少选择一件需要整理的物品。"
            return
        }
        var plan = dependencies.planningService.makePlan(
            for: currentSpace,
            selectedItems: selectedItems,
            style: selectedStyle,
            timeBudget: selectedTimeBudget,
            goal: enrichedPlanningGoal,
            focusZone: enrichedFocusZone
        )

        spaces[index].activePlan = plan
        spaces[index].detectedItems = selectedItems
        selectedExecutionZones = Set(plan.steps.map(\.zone))
        if navigateToSpace {
            selectedTab = .space
        }
        persist()

        guard llmSettings.canRequest else { return }
        isPlanning = true
        defer { isPlanning = false }

        do {
            plan = try await dependencies.cloudPlanningService.refine(
                plan: plan,
                context: PlanningContext(
                    space: currentSpace,
                    selectedItems: selectedItems,
                    goal: planningGoal,
                    focusZone: focusZone,
                    selectedTags: selectedPlanningTags.sorted(),
                    recommendationMode: recommendationMode,
                    referenceImageData: referenceImage?.jpegData(compressionQuality: 0.72)
                ),
                settings: llmSettings
            )
            if let latestIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }) {
                spaces[latestIndex].activePlan = plan
                message = "云端 AI 已优化收纳方案。"
                persist()
            }
        } catch {
            message = "已生成本地方案；云端 AI 暂不可用：\(error.localizedDescription)"
        }
    }

    func completeStep(_ stepID: UUID) {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }),
              var plan = spaces[spaceIndex].activePlan,
              let stepIndex = plan.steps.firstIndex(where: { $0.id == stepID }),
              plan.steps[stepIndex].status == .active
        else { return }

        plan.steps[stepIndex].status = .done
        if let nextIndex = plan.steps.firstIndex(where: { $0.status == .pending }) {
            plan.steps[nextIndex].status = .active
        }
        spaces[spaceIndex].activePlan = plan
        if plan.steps.allSatisfy({ $0.status == .done }) {
            message = "步骤已完成，请拍摄或导入整理后的照片生成对比成果。"
        }
        persist()
    }

    func finishActivePlan(afterImage: UIImage) {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }),
              var plan = spaces[spaceIndex].activePlan,
              plan.steps.allSatisfy({ $0.status == .done })
        else { return }

        do {
            spaces[spaceIndex].afterImageName = try saveImage(afterImage, prefix: "after")
            spaces[spaceIndex].hasVerifiedComparison = true
            plan.completedAt = Date()
            finishActivePlan(in: spaceIndex, plan: plan)
            persist()
        } catch {
            message = "保存整理后照片失败：\(error.localizedDescription)"
        }
    }

    func shareLatestCompletion() {
        guard let selectedSpaceID,
              let space = spaces.first(where: { $0.id == selectedSpaceID }),
              let plan = space.completedPlans.first
        else {
            message = "还没有可分享的完成记录。"
            return
        }
        guard space.hasVerifiedComparison else {
            message = "请先拍摄或导入完成照，再分享真实的前后对比。"
            return
        }

        if communityCases.contains(where: {
            $0.author == "我"
                && $0.title == "\(space.name) \(plan.timeBudget.title)整理"
                && $0.beforeImageName == space.beforeImageName
                && $0.afterImageName == space.afterImageName
        }) {
            message = "这次成果已经分享到社区。"
            return
        }

        let tags = Array(Set(space.detectedItems.map(\.category.rawValue))).prefix(4)
        let newCase = CommunityCase(
            title: "\(space.name) \(plan.timeBudget.title)整理",
            author: "我",
            style: plan.style,
            likes: 0,
            tags: Array(tags),
            beforeImageName: space.beforeImageName,
            afterImageName: space.afterImageName,
            beforeAssetName: space.beforeAssetName,
            afterAssetName: space.afterAssetName,
            durationText: plan.timeBudget.title,
            difficultyText: "已验证",
            items: space.detectedItems
        )
        communityCases.insert(newCase, at: 0)
        message = "已分享到社区，可被一键复刻。"
        persist()
    }

    func continueActivePlan() {
        selectedTab = .space
    }

    func replicate(_ communityCase: CommunityCase) {
        selectedStyle = communityCase.style
        selectedTimeBudget = .ten
        let sourceItems = communityCase.items.isEmpty ? selectedSpace.detectedItems : communityCase.items
        scannedItems = sourceItems.map { item in
            var selectedItem = item
            selectedItem.isSelected = true
            return selectedItem
        }
        makePlanFromScan()
        message = "已复刻「\(communityCase.title)」的整理风格。"
    }

    func toggleCommunityLike(_ id: UUID) {
        guard let index = communityCases.firstIndex(where: { $0.id == id }) else { return }
        if likedCommunityCaseIDs.remove(id) != nil {
            communityCases[index].likes = max(0, communityCases[index].likes - 1)
        } else {
            likedCommunityCaseIDs.insert(id)
            communityCases[index].likes += 1
        }
        persist()
    }

    func toggleCommunityFavorite(_ id: UUID) {
        if favoriteCommunityCaseIDs.remove(id) == nil {
            favoriteCommunityCaseIDs.insert(id)
        }
        persist()
    }

    func comments(for caseID: UUID) -> [CommunityComment] {
        (communityComments[caseID] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func commentCount(for caseID: UUID) -> Int {
        communityComments[caseID]?.count ?? 0
    }

    func addCommunityComment(to caseID: UUID, body: String) {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty,
              communityCases.contains(where: { $0.id == caseID })
        else { return }
        let comment = CommunityComment(caseID: caseID, body: trimmedBody)
        communityComments[caseID, default: []].append(comment)
        persist()
        message = "评论已发布。"
    }

    func toggleCommunityCommentLike(_ commentID: UUID, in caseID: UUID) {
        guard var comments = communityComments[caseID],
              let index = comments.firstIndex(where: { $0.id == commentID })
        else { return }
        comments[index].likes = comments[index].likes == 0 ? 1 : 0
        communityComments[caseID] = comments
        persist()
    }

    func toggleCommunityFollow(author: String) {
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAuthor.isEmpty, trimmedAuthor != "我" else { return }
        if followedCommunityAuthors.remove(trimmedAuthor) == nil {
            followedCommunityAuthors.insert(trimmedAuthor)
        }
        persist()
    }

    /// 老版本把点赞/收藏/关注写在 UserDefaults 里，这里搬进快照后清掉旧键，只执行一次。
    private static func migrateLegacyCommunityReactionsIfNeeded(
        liked: inout Set<UUID>,
        favorited: inout Set<UUID>,
        followed: inout Set<String>
    ) {
        let legacyLiked = loadCommunityIDs(forKey: Self.communityLikesKey)
        let legacyFavorited = loadCommunityIDs(forKey: Self.communityFavoritesKey)
        let legacyFollowed = Set(UserDefaults.standard.stringArray(forKey: Self.communityFollowsKey) ?? [])
        guard !legacyLiked.isEmpty || !legacyFavorited.isEmpty || !legacyFollowed.isEmpty else { return }
        liked.formUnion(legacyLiked)
        favorited.formUnion(legacyFavorited)
        followed.formUnion(legacyFollowed)
        UserDefaults.standard.removeObject(forKey: Self.communityLikesKey)
        UserDefaults.standard.removeObject(forKey: Self.communityFavoritesKey)
        UserDefaults.standard.removeObject(forKey: Self.communityFollowsKey)
    }

    func resetDemo() {
        if !dependencies.credentialStore.deleteAPIKey() {
            #if DEBUG
            if CommandLine.arguments.contains("-SmartPawShowCommunity")
                || CommandLine.arguments.contains("-SmartPawShowCommunityDetail") {
                // Screenshot routes do not require resetting the API credential.
            } else {
                message = "API Key 无法从系统钥匙串删除，未执行数据重置。"
                return
            }
            #else
            message = "API Key 无法从系统钥匙串删除，未执行数据重置。"
            return
            #endif
        }
        cleanupStoredImages()
        let oldScheduleIDs = scheduleItems.map(\.id)
        let snapshot = DemoData.snapshot
        spaces = snapshot.spaces
        achievements = snapshot.achievements
        communityCases = snapshot.communityCases
        communityComments = snapshot.communityComments
        likedCommunityCaseIDs = []
        favoriteCommunityCaseIDs = []
        followedCommunityAuthors = []
        scheduleItems = snapshot.scheduleItems
        llmSettings = snapshot.llmSettings
        selectedSpaceID = spaces.first?.id
        scannedItems = []
        capturedImage = nil
        selectedStyle = .quickReset
        selectedTimeBudget = .ten
        planningGoal = ""
        focusZone = ""
        selectedPlanningTags = []
        recommendationMode = .balanced
        referenceImage = nil
        selectedExecutionZones = []
        latestUnlockedAchievement = nil
        persist()
        Task {
            for id in oldScheduleIDs {
                await cancelNotification(for: id)
            }
            await reconcileScheduleNotifications()
        }
    }

    func imageURL(for imageName: String) -> URL? {
        guard !imageName.isEmpty else { return nil }
        let url = imageDirectory.appendingPathComponent(imageName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func clearMessage() {
        message = nil
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        hasSelectedLanguage = true
        UserDefaults.standard.set(language.rawValue, forKey: Self.languageKey)
    }

    func showMessage(_ text: String) {
        message = text
    }

    @discardableResult
    func updateLLMSettings(_ settings: LLMSettings) -> Bool {
        let normalized = normalizedLLMSettings(settings)
        guard dependencies.credentialStore.saveAPIKey(normalized.apiKey) else {
            llmConnectionState = .failure("API Key 无法写入系统钥匙串，请检查设备安全设置。")
            return false
        }
        llmSettings = normalized
        llmConnectionState = .idle
        persist()
        return true
    }

    @discardableResult
    func saveLLMSettings(_ settings: LLMSettings) -> Bool {
        if settings.isEnabled, let validationError = llmValidationError(for: settings) {
            llmConnectionState = .failure(validationError)
            return false
        }
        guard updateLLMSettings(settings) else { return false }
        message = "AI 设置已保存。"
        return true
    }

    func testLLMConnection(_ settings: LLMSettings) async {
        guard let endpoint = validatedLLMEndpoint(for: settings) else {
            llmConnectionState = .failure(llmValidationError(for: settings) ?? "Endpoint 无效。")
            return
        }

        llmConnectionState = .testing
        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": settings.model.trimmingCharacters(in: .whitespacesAndNewlines),
                "input": "Reply with OK.",
                "max_output_tokens": 8
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMConnectionTestError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw LLMConnectionTestError.httpStatus(httpResponse.statusCode)
            }
            guard Self.isValidResponsesPayload(data) else {
                throw LLMConnectionTestError.invalidPayload
            }

            let normalized = normalizedLLMSettings(settings)
            guard dependencies.credentialStore.saveAPIKey(normalized.apiKey) else {
                throw LLMConnectionTestError.keychainWriteFailed
            }
            llmSettings = normalized
            persist()
            llmConnectionState = .success("连接成功，Endpoint、API Key 与模型均可用。")
        } catch {
            llmConnectionState = .failure(connectionErrorMessage(for: error))
        }
    }

    func sendChatMessage(message: String, history: [[String: String]]) async throws -> String {
        guard llmSettings.canRequest else { throw ChatError.notConfigured }
        guard let url = URL(string: llmSettings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ChatError.invalidResponse
        }
        var input: [[String: Any]] = []
        let context = currentChatContext()
        input.append(["role": "system", "content": "你是灵爪收纳助手。请基于当前扫描和空间信息，用简洁、具体、可执行的中文回答。\n\(context)"])
        for item in history.prefix(12) {
            guard let role = item["role"], let text = item["text"], !text.isEmpty else { continue }
            input.append(["role": role == "assistant" ? "assistant" : "user", "content": text])
        }
        input.append(["role": "user", "content": message])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(llmSettings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": llmSettings.model,
            "input": input,
            "max_output_tokens": 500
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChatError.httpFailure
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChatError.invalidResponse
        }
        if let text = object["output_text"] as? String, !text.isEmpty { return text }
        if let output = object["output"] as? [[String: Any]] {
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for part in content where part["type"] as? String == "output_text" {
                        if let text = part["text"] as? String, !text.isEmpty { return text }
                    }
                }
            }
        }
        throw ChatError.invalidResponse
    }

    private func currentChatContext() -> String {
        let space = spaces.first(where: { $0.id == selectedSpaceID })
        let items = (scannedItems.isEmpty ? space?.detectedItems ?? [] : scannedItems)
            .filter(\.isSelected).map { "\($0.name)(\($0.category.rawValue))" }.joined(separator: "、")
        return "空间：\(space?.name ?? "未选择空间")；扫描物品：\(items.isEmpty ? "暂无" : items)；风格：\(selectedStyle.rawValue)；时间预算：\(selectedTimeBudget.title)"
    }

    func llmValidationError(for settings: LLMSettings) -> String? {
        let endpoint = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.fragment == nil,
              scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host.lowercased()))
        else {
            return "Endpoint 必须是有效的 HTTPS URL；本机服务可使用 HTTP localhost。"
        }

        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 8, key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "API Key 不能为空、不能包含空格，且长度至少为 8 个字符。"
        }

        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "Model 不能为空，也不能包含空格。"
        }
        return nil
    }

    func toggleScheduleItem(_ id: UUID) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == id }) else { return }
        scheduleItems[index].isDone.toggle()
        let item = scheduleItems[index]
        persist()
        Task {
            if item.isDone {
                await cancelNotification(for: item.id)
            } else {
                await scheduleNotification(for: item)
            }
        }
    }

    func addScheduleItem(title: String, dueText: String, note: String) {
        let migrated = ScheduleItem(title: title, spaceName: selectedSpace.name, dueText: dueText, note: note)
        addScheduleItem(title: title, dueDate: migrated.dueDate, note: note)
    }

    func addScheduleItem(title: String, dueDate: Date, note: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let item = ScheduleItem(
            title: trimmedTitle,
            spaceName: selectedSpace.name,
            dueDate: dueDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "复盘本次整理状态" : note
        )
        scheduleItems.insert(item, at: 0)
        persist()
        Task { await scheduleNotification(for: item) }
    }

    func updateScheduleItem(_ item: ScheduleItem) {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.title.isEmpty else { return }
        scheduleItems[index] = updated
        persist()
        Task {
            await cancelNotification(for: updated.id)
            if !updated.isDone { await scheduleNotification(for: updated) }
        }
    }

    func deleteScheduleItem(_ id: UUID) {
        scheduleItems.removeAll { $0.id == id }
        persist()
        Task { await cancelNotification(for: id) }
    }

    func requestNotificationAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshNotificationAuthorizationState()
            await reconcileScheduleNotifications()
        } catch {
            notificationAuthorizationState = .denied
            message = "无法开启日程提醒：\(error.localizedDescription)"
        }
    }

    func refreshNotificationAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            notificationAuthorizationState = .notDetermined
        case .denied:
            notificationAuthorizationState = .denied
        case .authorized:
            notificationAuthorizationState = .authorized
        case .provisional, .ephemeral:
            notificationAuthorizationState = .provisional
        @unknown default:
            notificationAuthorizationState = .unknown
        }
    }

    func isAchievementUnlocked(_ achievement: Achievement) -> Bool {
        switch achievement.title {
        case "启动不拖延": !catalogItems.isEmpty
        case "十分钟复原": completedPlans.contains { $0.timeBudget == .ten }
        case "秩序收藏家": catalogItems.count >= 5
        case "同款复刻": !favoriteCommunityCaseIDs.isEmpty
        case "前后对比": spaces.contains { $0.hasVerifiedComparison && !$0.beforeImageName.isEmpty && !$0.afterImageName.isEmpty && !$0.completedPlans.isEmpty }
        case "凌乱终结者": completedCount > 0
        default: achievements.contains(where: { $0.id == achievement.id })
        }
    }

    private func validatedLLMEndpoint(for settings: LLMSettings) -> URL? {
        guard llmValidationError(for: settings) == nil else { return nil }
        return URL(string: settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func normalizedLLMSettings(_ settings: LLMSettings) -> LLMSettings {
        LLMSettings(
            isEnabled: settings.isEnabled,
            endpoint: settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func isValidResponsesPayload(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let outputText = object["output_text"] as? String, !outputText.isEmpty { return true }
        guard let output = object["output"] as? [[String: Any]], !output.isEmpty else { return false }
        return output.contains { item in
            guard let content = item["content"] as? [[String: Any]] else { return false }
            return content.contains { contentItem in
                guard let text = contentItem["text"] as? String else { return false }
                return !text.isEmpty
            }
        }
    }

    private func connectionErrorMessage(for error: Error) -> String {
        if let testError = error as? LLMConnectionTestError {
            return testError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return "连接超时，请检查 Endpoint 或网络。"
            case .notConnectedToInternet: return "当前无网络连接。"
            case .cannotFindHost, .cannotConnectToHost: return "无法连接 Endpoint，请检查地址与服务状态。"
            default: return "连接失败：\(urlError.localizedDescription)"
            }
        }
        return "连接测试失败：\(error.localizedDescription)"
    }

    private func reconcileScheduleNotifications() async {
        guard notificationAuthorizationState == .authorized || notificationAuthorizationState == .provisional else { return }
        for item in scheduleItems where !item.isDone && item.dueDate > Date() {
            await scheduleNotification(for: item)
        }
    }

    private func scheduleNotification(for item: ScheduleItem) async {
        guard !item.isDone, item.dueDate > Date() else {
            await cancelNotification(for: item.id)
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        guard let current = scheduleItems.first(where: { $0.id == item.id }),
              !current.isDone,
              current.dueDate == item.dueDate,
              current.title == item.title
        else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.note.isEmpty ? "该整理一下 \(item.spaceName) 了。" : item.note
        content.sound = .default
        content.userInfo = ["scheduleItemID": item.id.uuidString]
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.dueDate)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: item.id),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            guard let latest = scheduleItems.first(where: { $0.id == item.id }),
                  !latest.isDone,
                  latest.dueDate == item.dueDate,
                  latest.title == item.title
            else {
                await cancelNotification(for: item.id)
                return
            }
        } catch {
            message = "日程已保存，但提醒调度失败：\(error.localizedDescription)"
        }
    }

    private func cancelNotification(for id: UUID) async {
        let identifier = notificationIdentifier(for: id)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func notificationIdentifier(for id: UUID) -> String {
        "smartpaw.schedule.\(id.uuidString)"
    }

    private func finishActivePlan(in index: Int, plan: StoragePlan) {
        spaces[index].completedPlans.insert(plan, at: 0)
        spaces[index].activePlan = nil
        spaces[index].lastOrganizedAt = plan.completedAt ?? Date()
        if !achievements.contains(where: { $0.title == "凌乱终结者" }) {
            let achievement = Achievement(title: "凌乱终结者", subtitle: "完成一次完整收纳闭环", iconName: "sparkles")
            achievements.insert(achievement, at: 0)
            latestUnlockedAchievement = achievement
        }
        message = "收纳完成，已生成前后对比与成就记录。"
    }

    private var enrichedFocusZone: String {
        let zone = focusZone.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = selectedPlanningTags.sorted()
        guard !tags.isEmpty else { return zone }
        let tagText = tags.joined(separator: "、")
        return zone.isEmpty ? "重点标签：\(tagText)" : "\(zone) · 重点标签：\(tagText)"
    }

    private var enrichedPlanningGoal: String {
        let goal = planningGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let modeRequirement: String
        switch recommendationMode {
        case .balanced:
            modeRequirement = "兼顾现有预算、取用效率与维护成本"
        case .budget:
            modeRequirement = "优先复用现有容器，不新增非必要购买"
        case .premium:
            modeRequirement = "优先长期稳定、标签化与完整复盘"
        }
        return goal.isEmpty ? modeRequirement : "\(goal)；\(modeRequirement)"
    }

    private var imageDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("SmartPawImages", isDirectory: true)
    }

    private func saveImage(_ image: UIImage, prefix: String) throws -> String {
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let fileName = "\(prefix)-\(UUID().uuidString).jpg"
        let url = imageDirectory.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: [.atomic])
        return fileName
    }

    private func cleanupStoredImages() {
        guard FileManager.default.fileExists(atPath: imageDirectory.path) else { return }
        try? FileManager.default.removeItem(at: imageDirectory)
    }

    private func persist() {
        do {
            try dependencies.storageStore.saveState(
                AppStateSnapshot(
                    spaces: spaces,
                    achievements: achievements,
                    communityCases: communityCases,
                    communityComments: communityComments,
                    scheduleItems: scheduleItems,
                    llmSettings: llmSettings,
                    likedCommunityCaseIDs: likedCommunityCaseIDs,
                    favoriteCommunityCaseIDs: favoriteCommunityCaseIDs,
                    followedCommunityAuthors: followedCommunityAuthors
                )
            )
        } catch {
            message = "保存失败：\(error.localizedDescription)"
        }
    }

    private func removingItemReference(_ itemID: UUID, from plan: StoragePlan?) -> StoragePlan? {
        guard var plan else { return nil }
        plan.steps = plan.steps.map { step in
            var updated = step
            updated.itemIDs.removeAll { $0 == itemID }
            return updated
        }
        return plan
    }

    private static func loadCommunityIDs(forKey key: String) -> Set<UUID> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private static func detectedItemFromRoomCategory(_ rawCategory: String) -> DetectedItem {
        let raw = rawCategory.lowercased()
        let category: ItemCategory
        let name: String
        if raw.contains("television") {
            category = .electronics
            name = "电视设备"
        } else if raw.contains("bed") || raw.contains("clothes") {
            category = .clothes
            name = raw.contains("bed") ? "床铺区域" : "衣物区域"
        } else if raw.contains("chair") {
            category = .tools
            name = "座椅"
        } else if raw.contains("table") || raw.contains("desk") {
            category = .tools
            name = "桌面区域"
        } else if raw.contains("storage") || raw.contains("shelf") || raw.contains("cabinet") {
            category = .tools
            name = "柜架收纳区"
        } else {
            category = .tools
            name = "空间家具"
        }
        return DetectedItem(name: name, category: category, confidence: 1, suggestedZone: category.suggestedZone)
    }
}

private enum LLMConnectionTestError: LocalizedError {
    case invalidResponse
    case invalidPayload
    case keychainWriteFailed
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "服务未返回有效的 HTTP 响应。"
        case .invalidPayload:
            "服务返回成功状态，但内容不是有效的 Responses API 响应。"
        case .keychainWriteFailed:
            "连接成功，但 API Key 无法写入系统钥匙串。"
        case .httpStatus(401), .httpStatus(403):
            "鉴权失败，请检查 API Key（HTTP 401/403）。"
        case .httpStatus(404):
            "Endpoint 不存在（HTTP 404），请确认 Responses API 路径。"
        case let .httpStatus(status):
            "服务返回 HTTP \(status)，请检查模型名、额度或服务配置。"
        }
    }
}

#if DEBUG
extension AppViewModel {
    func runRealVisionSampleScanForScreenshotIfRequested() async {
        guard CommandLine.arguments.contains("-SmartPawAutoVisionScan")
            || CommandLine.arguments.contains("-SmartPawAutoActivePlan")
            || CommandLine.arguments.contains("-SmartPawAutoCompletedDemo")
            || CommandLine.arguments.contains("-SmartPawAutoCaptureCamera")
            || CommandLine.arguments.contains("-SmartPawAutoCaptureSample")
            || CommandLine.arguments.contains("-SmartPawShowCommunity")
            || CommandLine.arguments.contains("-SmartPawShowCommunityDetail")
            || CommandLine.arguments.contains("-SmartPawShowCommunityComments")
            || CommandLine.arguments.contains("-SmartPawShowCommunityPlan")
            || CommandLine.arguments.contains("-SmartPawShowProfile")
            || CommandLine.arguments.contains("-SmartPawShowProfilePlans")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadges")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadgeDetail")
            || CommandLine.arguments.contains("-SmartPawShowProfileLockedBadgeDetail")
        else { return }

        if CommandLine.arguments.contains("-SmartPawAutoCaptureSample") {
            selectedTab = .capture
            clearMessage()
            await scanBundledSample(assetName: requestedSampleAsset())
            selectedTab = .capture
            clearMessage()
            return
        }

        if CommandLine.arguments.contains("-SmartPawAutoCaptureCamera") {
            resetDemo()
            selectedTab = .capture
            clearMessage()
            return
        }

        if CommandLine.arguments.contains("-SmartPawShowCommunity")
            || CommandLine.arguments.contains("-SmartPawShowCommunityDetail")
            || CommandLine.arguments.contains("-SmartPawShowCommunityComments")
            || CommandLine.arguments.contains("-SmartPawShowCommunityPlan") {
            selectedTab = .community
            clearMessage()
            return
        }

        if CommandLine.arguments.contains("-SmartPawShowProfile")
            || CommandLine.arguments.contains("-SmartPawShowProfilePlans")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadges")
            || CommandLine.arguments.contains("-SmartPawShowProfileBadgeDetail")
            || CommandLine.arguments.contains("-SmartPawShowProfileLockedBadgeDetail") {
            selectedTab = .profile
            clearMessage()
            return
        }

        resetDemo()
        planningGoal = "截图验证真实识别效果"
        focusZone = "书桌"
        await scanBundledSample(assetName: AppSampleAssets.messyDesk)
        if CommandLine.arguments.contains("-SmartPawAutoVisionScan") {
            selectedTab = .capture
            clearMessage()
            return
        }

        await makePlanFromScanUsingCloudIfAvailable()
        if CommandLine.arguments.contains("-SmartPawAutoActivePlan") {
            selectedTab = .space
            clearMessage()
            return
        }

        finishAllActiveStepsForScreenshot()
        guard let afterImage = UIImage(named: AppSampleAssets.clutteredStudy) else { return }
        finishActivePlan(afterImage: afterImage)
        shareLatestCompletion()
        if CommandLine.arguments.contains("-SmartPawShowCommunity") {
            selectedTab = .community
        } else if CommandLine.arguments.contains("-SmartPawShowProfile") {
            selectedTab = .profile
        } else {
            selectedTab = .space
        }
        clearMessage()
    }

    private func requestedSampleAsset() -> String {
        guard let index = CommandLine.arguments.firstIndex(of: "-SmartPawSampleAsset"),
              index + 1 < CommandLine.arguments.count
        else { return AppSampleAssets.messyDesk }
        let requested = CommandLine.arguments[index + 1]
        return AppSampleAssets.evaluationSamples.contains(requested) ? requested : AppSampleAssets.messyDesk
    }

    private func finishAllActiveStepsForScreenshot() {
        guard let plan = activePlan else { return }
        plan.steps.forEach { completeStep($0.id) }
    }
}

#endif
