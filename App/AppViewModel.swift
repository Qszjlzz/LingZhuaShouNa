import Foundation
import UIKit
import UserNotifications

private enum ChatError: LocalizedError {
    case notConfigured
    case httpFailure(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "尚未配置可用的 AI API，请先在「我的 - AI 设置」中保存 Endpoint、API Key 和模型。"
        case .httpFailure(let detail): return "AI 服务请求失败" + Self.detailSuffix(detail)
        case .invalidResponse(let detail): return "AI 返回内容无法解析" + Self.detailSuffix(detail)
        }
    }

    private static func detailSuffix(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "，请检查 API Key、模型与 Endpoint。" }
        return "：" + String(trimmed.prefix(140))
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
    @Published private(set) var isPresentationMode = false
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
    /// 最近一次图片识别是否已经成功写入本地快照。桥接层用它避免把内存结果误报成已保存。
    private(set) var lastScanPersisted = true
    @Published private(set) var isPlanning = false
    @Published private(set) var message: String?

    let dependencies: AppDependencies
    private let defaults: UserDefaults
    private let documentsDirectory: URL
    private let imageGenerationReset: () -> Bool

    private static let communityLikesKey = "SmartPaw.community.likedCaseIDs"
    private static let communityFavoritesKey = "SmartPaw.community.favoriteCaseIDs"
    private static let communityFollowsKey = "SmartPaw.community.followedAuthors"
    private static let languageKey = "SmartPaw.appLanguage"
    private var activeScanID: UUID?
    private var scanContextID = UUID()
    private var activePlanningID: UUID?
    private var llmSettingsGeneration = 0
    private var storageRecoveryMode = false
    /// 连拍时每张照片都会起一轮扫描，用递增代号区分先后，避免旧一轮的结果覆盖新一轮。
    private var scanGeneration = 0
    /// 同一批拍摄里云端识别只调用一次，标记在这里。
    /// 扫描页的中间结果会先写入本地以便跨任务读取；用户取消时恢复进入扫描页前的快照。
    private struct PhotoScanSessionSnapshot {
        let spaceID: UUID?
        let space: StorageSpace?
        let scannedItems: [DetectedItem]
        let capturedImage: UIImage?
    }
    private var photoScanSessionSnapshot: PhotoScanSessionSnapshot?
    private var photoScanSessionImageNames: Set<String> = []

    init(
        dependencies: AppDependencies,
        defaults: UserDefaults = .standard,
        documentsDirectory: URL? = nil,
        imageGenerationReset: @escaping () -> Bool = { ImageGenerationManager.shared.reset() }
    ) {
        self.dependencies = dependencies
        self.defaults = defaults
        self.documentsDirectory = documentsDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.imageGenerationReset = imageGenerationReset
        isPresentationMode = (dependencies.storageStore as? PresentationStorageStore)?.isPresentationMode ?? false
        let storedLanguage = defaults.string(forKey: Self.languageKey)
            .flatMap(AppLanguage.init(rawValue:))
        // New installs start in Chinese so the first-run picker is readable
        // before the user makes a language choice.
        language = storedLanguage ?? .chinese
        hasSelectedLanguage = storedLanguage != nil
        let snapshot: AppStateSnapshot
        let loadErrorMessage: String?
        do {
            snapshot = try dependencies.storageStore.loadState() ?? AppStateSnapshot.initial
            loadErrorMessage = nil
        } catch {
            snapshot = AppStateSnapshot.initial
            storageRecoveryMode = true
            loadErrorMessage = "本地数据读取失败，已进入恢复模式；原文件未被删除。\(error.localizedDescription)"
        }
        let persistedSpaces = snapshot.spaces.isEmpty ? AppStateSnapshot.initial.spaces : snapshot.spaces
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
        scheduleItems = snapshot.scheduleItems
        var restoredLLMSettings = snapshot.llmSettings
        if !restoredLLMSettings.hasCloudConsent { restoredLLMSettings.isEnabled = false }
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
        if !isPresentationMode {
            Self.migrateLegacyCommunityReactionsIfNeeded(
                defaults: defaults,
                liked: &likedCommunityCaseIDs,
                favorited: &favoriteCommunityCaseIDs,
                followed: &followedCommunityAuthors
            )
        }
        selectedSpaceID = spaces.first?.id
        selectedExecutionZones = Set(spaces.first?.activePlan?.steps.map(\.zone) ?? [])
        message = credentialMigrationFailed
            ? "旧版 API Key 无法迁移到系统钥匙串，原数据文件已保留。"
            : loadErrorMessage
        #if DEBUG
        message = nil
        #endif
        #if DEBUG
        if let screenshotTab = CommandLine.arguments.drop(while: { $0 != "-SmartPawScreenshotTab" }).dropFirst().first,
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
        // 拍照/AR 识别需要知道用户当前保存的 AI 设置，用来决定要不要走云端多模态识别。
        if let router = dependencies.scanService as? RecognitionRouter {
            router.settingsProvider = { [weak self] in self?.llmSettings ?? .default }
        }
        #if DEBUG
        // 启动时用 bundle 里的真实测试图跑一遍本地识别，结果落到文件，方便排查识别链路。
        if CommandLine.arguments.contains("-SmartPawRunSelfTest") {
            let documents = self.documentsDirectory
            Task.detached(priority: .utility) {
                let text = await YOLOSegmentationScanService.runSelfTest()
                try? text.write(to: documents.appendingPathComponent("smartpaw-selftest.txt"), atomically: true, encoding: .utf8)
            }
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

    @discardableResult
    func setPresentationMode(_ enabled: Bool) -> Bool {
        guard let store = dependencies.storageStore as? PresentationStorageStore else {
            message = "当前运行环境不支持切换演示档案。"
            return false
        }
        guard enabled != isPresentationMode else { return true }
        do {
            let snapshot = try store.setPresentationMode(enabled)
            for imageName in photoScanSessionImageNames {
                try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(imageName))
            }
            isPresentationMode = enabled
            applyAccountSnapshot(snapshot)
            if !enabled {
                Self.migrateLegacyCommunityReactionsIfNeeded(
                    defaults: defaults,
                    liked: &likedCommunityCaseIDs,
                    favorited: &favoriteCommunityCaseIDs,
                    followed: &followedCommunityAuthors
                )
                Task { await reconcileScheduleNotifications() }
            }
            return true
        } catch {
            message = "切换档案失败，当前数据已保留：\(error.localizedDescription)"
            return false
        }
    }

    private func applyAccountSnapshot(_ snapshot: AppStateSnapshot) {
        invalidateScanContext()
        activePlanningID = nil
        isPlanning = false
        storageRecoveryMode = false
        photoScanSessionSnapshot = nil
        photoScanSessionImageNames.removeAll()
        spaces = snapshot.spaces.isEmpty ? AppStateSnapshot.initial.spaces : snapshot.spaces
        achievements = snapshot.achievements
        communityCases = snapshot.communityCases
        communityComments = snapshot.communityComments
        likedCommunityCaseIDs = snapshot.likedCommunityCaseIDs
        favoriteCommunityCaseIDs = snapshot.favoriteCommunityCaseIDs
        followedCommunityAuthors = snapshot.followedCommunityAuthors
        scheduleItems = snapshot.scheduleItems
        var restoredSettings = snapshot.llmSettings
        restoredSettings.apiKey = dependencies.credentialStore.loadAPIKey() ?? llmSettings.apiKey
        if !restoredSettings.hasCloudConsent { restoredSettings.isEnabled = false }
        llmSettingsGeneration += 1
        llmSettings = restoredSettings
        llmConnectionState = .idle
        selectedSpaceID = spaces.first?.id
        scannedItems = []
        capturedImage = nil
        referenceImage = nil
        selectedStyle = .quickReset
        selectedTimeBudget = .ten
        planningGoal = ""
        focusZone = ""
        selectedPlanningTags = []
        recommendationMode = .balanced
        selectedExecutionZones = Set(spaces.first?.activePlan?.steps.map(\.zone) ?? [])
        latestUnlockedAchievement = nil
        lastScanPersisted = true
        message = nil
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
        invalidateScanContext()
        selectedSpaceID = id
        scannedItems = []
        capturedImage = nil
        referenceImage = nil
        selectedExecutionZones = Set(spaces.first(where: { $0.id == id })?.activePlan?.steps.map(\.zone) ?? [])
    }

    @discardableResult
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
        let previousSelectedSpaceID = selectedSpaceID
        spaces.append(space)
        invalidateScanContext()
        selectedSpaceID = space.id
        scannedItems = []
        capturedImage = nil
        referenceImage = nil
        guard persist() else {
            spaces.removeAll { $0.id == space.id }
            selectedSpaceID = previousSelectedSpaceID ?? spaces.first?.id
            invalidateScanContext()
            return nil
        }
        return space.id
    }

    @discardableResult
    func renameSpace(_ id: UUID, name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = spaces.firstIndex(where: { $0.id == id }) else { return false }
        let previous = spaces[index]
        spaces[index].name = trimmed
        guard persist() else { spaces[index] = previous; return false }
        return true
    }

    @discardableResult
    func deleteSpace(_ id: UUID) -> Bool {
        guard spaces.count > 1, let index = spaces.firstIndex(where: { $0.id == id }) else {
            message = "至少保留一个空间。"
            return false
        }
        let previousSpaces = spaces
        let previousSelectedSpaceID = selectedSpaceID
        spaces.remove(at: index)
        if selectedSpaceID == id { selectSpace(spaces[0].id) }
        guard persist() else {
            spaces = previousSpaces
            selectedSpaceID = previousSelectedSpaceID
            return false
        }
        return true
    }

    @discardableResult
    func replaceScannedItems(_ items: [DetectedItem]) -> Bool {
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else {
            message = "请先选择一个有效空间。"
            return false
        }
        let previousItems = scannedItems
        let previousSpace = spaces[index]
        scannedItems = items
        spaces[index].detectedItems = items
        guard persist() else {
            scannedItems = previousItems
            spaces[index] = previousSpace
            return false
        }
        return true
    }

    private func invalidateScanContext() {
        scanContextID = UUID()
        activeScanID = nil
        scanGeneration += 1
        isScanning = false
    }

    func cancelScanWork() {
        invalidateScanContext()
        guard let snapshot = photoScanSessionSnapshot else { return }
        if let spaceID = snapshot.spaceID {
            if let index = spaces.firstIndex(where: { $0.id == spaceID }), let space = snapshot.space {
                spaces[index] = space
            }
        }
        scannedItems = snapshot.scannedItems
        capturedImage = snapshot.capturedImage
        for imageName in photoScanSessionImageNames {
            try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(imageName))
        }
        photoScanSessionImageNames.removeAll()
        photoScanSessionSnapshot = nil
        lastScanPersisted = persist()
    }

    func beginPhotoScanSession() {
        invalidateScanContext()
        let space = selectedSpaceID.flatMap { id in spaces.first(where: { $0.id == id }) }
        photoScanSessionSnapshot = PhotoScanSessionSnapshot(
            spaceID: selectedSpaceID,
            space: space,
            scannedItems: scannedItems,
            capturedImage: capturedImage
        )
        photoScanSessionImageNames.removeAll()
        activeScanID = UUID()
        scannedItems = []
        isScanning = false
    }

    /// The scan flow calls this after its confirmation request has been persisted.
    /// From this point onward cancelling the view must not restore the pre-scan data.
    func commitPhotoScanSession() {
        photoScanSessionSnapshot = nil
        photoScanSessionImageNames.removeAll()
    }

    func scanImage(_ image: UIImage) async {
        lastScanPersisted = true
        let scanID = UUID()
        let spaceID = selectedSpaceID
        let contextID = scanContextID
        let previousCapturedImage = capturedImage
        let previousScannedItems = scannedItems
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
            guard !Task.isCancelled, activeScanID == scanID, scanContextID == contextID, selectedSpaceID == spaceID else { return }
            if let index = spaces.firstIndex(where: { $0.id == spaceID }) {
                let previousSpace = spaces[index]
                let imageName = try saveImage(image, prefix: "before")
                photoScanSessionImageNames.insert(imageName)
                scannedItems = results
                spaces[index].detectedItems = results
                spaces[index].beforeImageName = imageName
                spaces[index].beforeAssetName = nil
                spaces[index].hasVerifiedComparison = false
                guard persist() else {
                    lastScanPersisted = false
                    spaces[index] = previousSpace
                    scannedItems = previousScannedItems
                    capturedImage = previousCapturedImage
                    try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(imageName))
                    photoScanSessionImageNames.remove(imageName)
                    return
                }
            }
        } catch {
            guard !Task.isCancelled, activeScanID == scanID, scanContextID == contextID, selectedSpaceID == spaceID else { return }
            scannedItems = []
            message = "扫描失败：\(error.localizedDescription)"
        }
    }

    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        message = "照片已保存，可继续开始扫描。"
    }

    /// Merges complementary views of the same space before the user confirms the result.
    @discardableResult
    func scanImages(_ images: [UIImage], accumulate: Bool = false) async -> [DetectedItem] {
        guard let primaryImage = images.first else { return [] }
        lastScanPersisted = true
        let spaceID = selectedSpaceID
        let contextID = scanContextID
        let previousSpace = spaces.first(where: { $0.id == spaceID })
        let previousScannedItems = scannedItems
        let previousCapturedImage = capturedImage
        let scanID = UUID()
        activeScanID = scanID
        scanGeneration += 1
        let generation = scanGeneration
        capturedImage = primaryImage
        isScanning = true
        defer {
            // 只有最后一轮结束时才收起 loading，否则前面几张一回来就把状态清掉了。
            if generation == scanGeneration { isScanning = false }
        }

        do {
            var mergedItems: [DetectedItem] = []
            // Every image is recognized independently; different views may reveal
            // additional possessions that are absent from the first photo.
            for image in images {
                let results = try await dependencies.scanService.scanImage(image)
                guard !Task.isCancelled, scanContextID == contextID, selectedSpaceID == spaceID else { return [] }
                // 这里不再用 activeScanID 提前退出：连拍时新一轮会把上一轮的代号顶掉，
                // 旧写法会让前面几张的识别结果直接作废，最后方案里只剩最后一张的东西。
                mergedItems.append(contentsOf: results)
            }

            let isLatest = generation == scanGeneration
            // accumulate：始终叠加，直接替换会让前面几张白拍。
            // 非 accumulate 但已有更新的一轮在跑：同样叠加，避免旧结果盖掉新结果。
            let base = (accumulate || !isLatest) ? scannedItems : []
            scannedItems = Self.merging(base, with: mergedItems)
            writeDiagnostics(note: "拍照识别（\(images.count) 张）", items: scannedItems)

            if let index = spaces.firstIndex(where: { $0.id == spaceID }) {
                spaces[index].detectedItems = scannedItems
                // before 图只认最后拍的那张，防止慢一轮的旧回调把图换回去。
                var savedImageName: String?
                if isLatest {
                    let imageName = try saveImage(primaryImage, prefix: "before")
                    photoScanSessionImageNames.insert(imageName)
                    savedImageName = imageName
                    spaces[index].beforeImageName = imageName
                    spaces[index].beforeAssetName = nil
                    spaces[index].hasVerifiedComparison = false
                }
                guard persist() else {
                    lastScanPersisted = false
                    if let previousSpace, let currentIndex = spaces.firstIndex(where: { $0.id == spaceID }) {
                        spaces[currentIndex] = previousSpace
                    }
                    scannedItems = previousScannedItems
                    capturedImage = previousCapturedImage
                    if let savedImageName {
                        try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(savedImageName))
                        photoScanSessionImageNames.remove(savedImageName)
                    }
                    return []
                }
            }
            return mergedItems
        } catch {
            guard !Task.isCancelled, generation == scanGeneration, scanContextID == contextID, selectedSpaceID == spaceID else { return [] }
            if let previousSpace, let currentIndex = spaces.firstIndex(where: { $0.id == spaceID }) {
                spaces[currentIndex] = previousSpace
            }
            scannedItems = accumulate ? previousScannedItems : []
            capturedImage = previousCapturedImage
            message = "扫描失败：\(error.localizedDescription)"
            lastScanPersisted = false
            return []
        }
    }

    /// Preserve separate instances, even when their names and categories match.
    /// Only the same stable ID is an update; cross-photo identity needs user review.
    static func merging(_ base: [DetectedItem], with newItems: [DetectedItem]) -> [DetectedItem] {
        var merged = base
        for item in newItems {
            if let index = merged.firstIndex(where: { $0.id == item.id }) {
                merged[index] = item
            } else {
                merged.append(item)
            }
        }
        return merged
    }

    func scanBundledSample(assetName: String) async {
        guard let image = UIImage(named: assetName) else {
            message = "找不到真实照片素材：\(assetName)。"
            return
        }
        await scanImage(image)
    }

    @discardableResult
    func importRoomPlanObjects(_ categoryNames: [String]) -> Bool {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID })
        else { return false }
        let imported = categoryNames.map(Self.detectedItemFromRoomCategory)
        guard !imported.isEmpty else {
            message = "空间结构已扫描，但没有识别到可归档的家具。"
            return false
        }
        let previousSpace = spaces[spaceIndex]
        let previousScannedItems = scannedItems
        spaces[spaceIndex].detectedItems.append(contentsOf: imported)
        scannedItems = imported
        guard persist() else {
            spaces[spaceIndex] = previousSpace
            scannedItems = previousScannedItems
            return false
        }
        message = "空间扫描完成，已归档 \(imported.count) 个家具与区域。"
        return true
    }

    func toggleScannedItem(_ itemID: UUID) {
        guard let index = scannedItems.firstIndex(where: { $0.id == itemID }) else { return }
        scannedItems[index].isSelected.toggle()
    }

    @discardableResult
    func updateScannedItem(_ item: DetectedItem) -> Bool {
        guard let index = scannedItems.firstIndex(where: { $0.id == item.id }) else { return false }
        let previousScannedItems = scannedItems
        let previousSpaces = spaces
        scannedItems[index] = item
        if let selectedSpaceID, let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }) {
            if let itemIndex = spaces[spaceIndex].detectedItems.firstIndex(where: { $0.id == item.id }) {
                spaces[spaceIndex].detectedItems[itemIndex] = item
            }
            guard persist() else {
                scannedItems = previousScannedItems
                spaces = previousSpaces
                return false
            }
        }
        return true
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

    @discardableResult
    func addManualItem(name: String, category: ItemCategory, suggestedZone: String? = nil, forScan: Bool = false) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            message = "请输入物品名称。"
            return false
        }
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else {
            message = "请先选择一个有效空间。"
            return false
        }

        let previousSpace = spaces[index]
        let previousItems = scannedItems
        let trimmedZone = suggestedZone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = DetectedItem(name: trimmedName, category: category, confidence: 1, suggestedZone: trimmedZone?.isEmpty == false ? trimmedZone : nil)
        spaces[index].detectedItems.insert(item, at: 0)
        if forScan {
            scannedItems.insert(item, at: 0)
        }
        guard persist() else {
            spaces[index] = previousSpace
            scannedItems = previousItems
            return false
        }
        message = "已添加「\(trimmedName)」到 \(spaces[index].name)。"
        return true
    }

    @discardableResult
    func removeCatalogItem(_ itemID: UUID) -> Bool {
        guard spaces.contains(where: { $0.detectedItems.contains(where: { $0.id == itemID }) })
                || scannedItems.contains(where: { $0.id == itemID }) else { return false }
        let previousSpaces = spaces
        let previousScannedItems = scannedItems
        for index in spaces.indices {
            spaces[index].detectedItems.removeAll { $0.id == itemID }
            spaces[index].activePlan = removingItemReference(itemID, from: spaces[index].activePlan)
            spaces[index].completedPlans = spaces[index].completedPlans.compactMap { removingItemReference(itemID, from: $0) }
        }
        scannedItems.removeAll { $0.id == itemID }
        guard persist() else {
            spaces = previousSpaces
            scannedItems = previousScannedItems
            return false
        }
        return true
    }

    @discardableResult
    func updateCatalogItem(_ item: DetectedItem) -> Bool {
        guard spaces.contains(where: { $0.detectedItems.contains(where: { $0.id == item.id }) })
                || scannedItems.contains(where: { $0.id == item.id }) else { return false }
        let previousSpaces = spaces
        let previousScannedItems = scannedItems
        for spaceIndex in spaces.indices {
            guard let itemIndex = spaces[spaceIndex].detectedItems.firstIndex(where: { $0.id == item.id }) else { continue }
            spaces[spaceIndex].detectedItems[itemIndex] = item
        }
        if let scannedIndex = scannedItems.firstIndex(where: { $0.id == item.id }) {
            scannedItems[scannedIndex] = item
        }
        guard persist() else {
            spaces = previousSpaces
            scannedItems = previousScannedItems
            return false
        }
        return true
    }

    @discardableResult
    func makePlanFromScan(navigateToSpace: Bool = true) -> Bool {
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else {
            message = "请先选择一个有效空间。"
            return false
        }
        let currentSpace = spaces[index]
        let selectedItems = scannedItems.isEmpty ? currentSpace.detectedItems : scannedItems
        guard selectedItems.contains(where: \.isSelected) else {
            message = "请至少选择一件需要整理的物品。"
            return false
        }
        let plan = dependencies.planningService.makePlan(
            for: currentSpace,
            selectedItems: selectedItems,
            style: selectedStyle,
            timeBudget: selectedTimeBudget,
            goal: enrichedPlanningGoal,
            focusZone: enrichedFocusZone
        )
        guard !plan.steps.isEmpty else {
            message = "未能生成有效整理步骤，请检查所选物品。"
            return false
        }
        let previousZones = selectedExecutionZones
        let previousTab = selectedTab
        spaces[index].activePlan = plan
        spaces[index].detectedItems = selectedItems
        selectedExecutionZones = Set(plan.steps.map(\.zone))
        if navigateToSpace {
            selectedTab = .space
        }
        guard persist() else {
            spaces[index] = currentSpace
            selectedExecutionZones = previousZones
            selectedTab = previousTab
            return false
        }
        return true
    }

    @discardableResult
    func makePlanFromScanUsingCloudIfAvailable(navigateToSpace: Bool = true) async -> Bool {
        guard let selectedSpaceID, let index = spaces.firstIndex(where: { $0.id == selectedSpaceID }) else {
            message = "请先选择一个有效空间。"
            return false
        }
        let currentSpace = spaces[index]
        let selectedItems = scannedItems.isEmpty ? currentSpace.detectedItems : scannedItems
        guard makePlanFromScan(navigateToSpace: navigateToSpace),
              var plan = spaces[index].activePlan else { return false }

        guard llmSettings.canRequest else { return true }
        let localPlan = plan
        let requestSettings = llmSettings
        let planningID = UUID()
        activePlanningID = planningID
        isPlanning = true
        defer { if activePlanningID == planningID { isPlanning = false } }

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
                settings: requestSettings
            )
            // Keep newer plans and already completed steps when an older request finishes late.
            guard activePlanningID == planningID,
                  llmSettings == requestSettings,
                  let latestIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }),
                  spaces[latestIndex].activePlan == localPlan else { return false }
            guard !plan.steps.isEmpty else {
                message = "云端方案没有有效步骤，已保留本地方案。"
                return false
            }
            let previousSpace = spaces[latestIndex]
            let previousZones = selectedExecutionZones
            spaces[latestIndex].activePlan = plan
            if self.selectedSpaceID == selectedSpaceID { selectedExecutionZones = Set(plan.steps.map(\.zone)) }
            guard persist() else {
                spaces[latestIndex] = previousSpace
                selectedExecutionZones = previousZones
                return false
            }
            message = "云端 AI 已优化收纳方案。"
            return true
        } catch {
            guard activePlanningID == planningID else { return false }
            message = "已生成本地方案；云端 AI 暂不可用：\(error.localizedDescription)"
            return true
        }
    }

    /// Restart the last completed plan without rewriting the archived result.
    @discardableResult
    func reusePlan(spaceID: UUID, planID: UUID) -> Bool {
        guard selectedSpaceID == spaceID,
              let index = spaces.firstIndex(where: { $0.id == spaceID }),
              let source = spaces[index].activePlan ?? spaces[index].completedPlans.first,
              source.id == planID, !source.steps.isEmpty else {
            message = "原方案已更新或不存在，请返回空间页重试。"
            return false
        }
        let previousSpace = spaces[index]
        let previousZones = selectedExecutionZones
        let steps = source.steps.enumerated().map { offset, step in
            StorageStep(title: step.title, detail: step.detail, zone: step.zone, status: offset == 0 ? .active : .pending, arHint: step.arHint, arMask: step.arMask, itemIDs: step.itemIDs)
        }
        spaces[index].activePlan = StoragePlan(style: source.style, timeBudget: source.timeBudget, summary: source.summary, toolList: source.toolList, steps: steps)
        selectedExecutionZones = Set(steps.map(\.zone))
        guard persist() else {
            spaces[index] = previousSpace
            selectedExecutionZones = previousZones
            return false
        }
        return true
    }

    @discardableResult
    func setPlanPaused(spaceID: UUID, planID: UUID, isPaused: Bool) -> Bool {
        guard let spaceIndex = spaces.firstIndex(where: { $0.id == spaceID }),
              var plan = spaces[spaceIndex].activePlan,
              plan.id == planID else {
            message = "方案已更新或不存在，请刷新后重试。"
            return false
        }
        guard plan.completedAt == nil,
              !plan.steps.isEmpty,
              !plan.steps.allSatisfy({ $0.status == .done }) else {
            message = "已完成的方案不能暂停或继续。"
            return false
        }
        guard plan.isPaused != isPaused else { return true }

        let previousSpace = spaces[spaceIndex]
        plan.isPaused = isPaused
        spaces[spaceIndex].activePlan = plan
        guard persist() else {
            spaces[spaceIndex] = previousSpace
            return false
        }
        return true
    }

    @discardableResult
    func completeStep(_ stepID: UUID) -> Bool {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }),
              var plan = spaces[spaceIndex].activePlan,
              !plan.isPaused,
              let stepIndex = plan.steps.firstIndex(where: { $0.id == stepID }),
              plan.steps[stepIndex].status == .active
        else {
            message = "当前步骤不可完成，请刷新方案后重试。"
            return false
        }

        let previousSpace = spaces[spaceIndex]
        plan.steps[stepIndex].status = .done
        if let nextIndex = plan.steps.firstIndex(where: { $0.status == .pending }) {
            plan.steps[nextIndex].status = .active
        }
        spaces[spaceIndex].activePlan = plan
        guard persist() else {
            spaces[spaceIndex] = previousSpace
            return false
        }
        if plan.steps.allSatisfy({ $0.status == .done }) {
            message = "步骤已完成，请拍摄或导入整理后的照片生成对比成果。"
        }
        return true
    }

    @discardableResult
    func finishActivePlan(afterImage: UIImage) -> Bool {
        guard let selectedSpaceID,
              let spaceIndex = spaces.firstIndex(where: { $0.id == selectedSpaceID }),
              var plan = spaces[spaceIndex].activePlan,
              !plan.steps.isEmpty,
              plan.steps.allSatisfy({ $0.status == .done })
        else {
            message = "请先完成方案中的整理步骤，再保存完成照。"
            return false
        }

        let previousSpace = spaces[spaceIndex]
        let previousAchievements = achievements
        let previousUnlockedAchievement = latestUnlockedAchievement
        do {
            let imageName = try saveImage(afterImage, prefix: "after")
            spaces[spaceIndex].afterImageName = imageName
            spaces[spaceIndex].afterAssetName = nil
            spaces[spaceIndex].hasVerifiedComparison = imageURL(for: previousSpace.beforeImageName) != nil
                || previousSpace.beforeAssetName != nil
            plan.completedAt = Date()
            finishActivePlan(in: spaceIndex, plan: plan)
            guard persist() else {
                spaces[spaceIndex] = previousSpace
                achievements = previousAchievements
                latestUnlockedAchievement = previousUnlockedAchievement
                do {
                    try FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(imageName))
                } catch {
                    message = (message ?? "完成记录保存失败。") + "；未归档的照片删除失败：\(error.localizedDescription)"
                }
                return false
            }
            return true
        } catch {
            message = "保存整理后照片失败：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func shareLatestCompletion() -> Bool {
        guard let selectedSpaceID,
              let space = spaces.first(where: { $0.id == selectedSpaceID }),
              let plan = space.completedPlans.first
        else {
            message = "还没有可分享的完成记录。"
            return false
        }
        guard space.hasVerifiedComparison else {
            message = "请先拍摄或导入完成照，再分享真实的前后对比。"
            return false
        }

        if communityCases.contains(where: {
            $0.author == "我"
                && $0.title == "\(space.name) \(plan.timeBudget.title)整理"
                && $0.beforeImageName == space.beforeImageName
                && $0.afterImageName == space.afterImageName
        }) {
            message = "这次成果已经分享到社区。"
            return true
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
        guard persist() else {
            communityCases.removeAll { $0.id == newCase.id }
            return false
        }
        message = "已分享到社区，可被一键复刻。"
        return true
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

    @discardableResult
    func toggleCommunityLike(_ id: UUID) -> Bool {
        guard let index = communityCases.firstIndex(where: { $0.id == id }) else { return false }
        let previousCases = communityCases
        let previousLiked = likedCommunityCaseIDs
        if likedCommunityCaseIDs.remove(id) != nil {
            communityCases[index].likes = max(0, communityCases[index].likes - 1)
        } else {
            likedCommunityCaseIDs.insert(id)
            communityCases[index].likes += 1
        }
        guard persist() else {
            communityCases = previousCases
            likedCommunityCaseIDs = previousLiked
            return false
        }
        return true
    }

    @discardableResult
    func toggleCommunityFavorite(_ id: UUID) -> Bool {
        guard communityCases.contains(where: { $0.id == id }) else { return false }
        let previous = favoriteCommunityCaseIDs
        if favoriteCommunityCaseIDs.remove(id) == nil {
            favoriteCommunityCaseIDs.insert(id)
        }
        guard persist() else { favoriteCommunityCaseIDs = previous; return false }
        return true
    }

    func comments(for caseID: UUID) -> [CommunityComment] {
        (communityComments[caseID] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func commentCount(for caseID: UUID) -> Int {
        communityComments[caseID]?.count ?? 0
    }

    @discardableResult
    func addCommunityComment(to caseID: UUID, body: String) -> Bool {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty,
              communityCases.contains(where: { $0.id == caseID })
        else { return false }
        let previousComments = communityComments
        let comment = CommunityComment(caseID: caseID, body: trimmedBody)
        communityComments[caseID, default: []].append(comment)
        guard persist() else { communityComments = previousComments; return false }
        message = "评论已发布。"
        return true
    }

    @discardableResult
    func toggleCommunityCommentLike(_ commentID: UUID, in caseID: UUID) -> Bool {
        guard var comments = communityComments[caseID],
              let index = comments.firstIndex(where: { $0.id == commentID })
        else { return false }
        let previousComments = communityComments
        comments[index].likes = comments[index].likes == 0 ? 1 : 0
        communityComments[caseID] = comments
        guard persist() else { communityComments = previousComments; return false }
        return true
    }

    @discardableResult
    func toggleCommunityFollow(author: String) -> Bool {
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAuthor.isEmpty, trimmedAuthor != "我" else { return false }
        let previous = followedCommunityAuthors
        if followedCommunityAuthors.remove(trimmedAuthor) == nil {
            followedCommunityAuthors.insert(trimmedAuthor)
        }
        guard persist() else { followedCommunityAuthors = previous; return false }
        return true
    }

    /// 老版本把点赞/收藏/关注写在 UserDefaults 里，这里搬进快照后清掉旧键，只执行一次。
    private static func migrateLegacyCommunityReactionsIfNeeded(
        defaults: UserDefaults,
        liked: inout Set<UUID>,
        favorited: inout Set<UUID>,
        followed: inout Set<String>
    ) {
        let legacyLiked = loadCommunityIDs(forKey: Self.communityLikesKey, defaults: defaults)
        let legacyFavorited = loadCommunityIDs(forKey: Self.communityFavoritesKey, defaults: defaults)
        let legacyFollowed = Set(defaults.stringArray(forKey: Self.communityFollowsKey) ?? [])
        guard !legacyLiked.isEmpty || !legacyFavorited.isEmpty || !legacyFollowed.isEmpty else { return }
        liked.formUnion(legacyLiked)
        favorited.formUnion(legacyFavorited)
        followed.formUnion(legacyFollowed)
        defaults.removeObject(forKey: Self.communityLikesKey)
        defaults.removeObject(forKey: Self.communityFavoritesKey)
        defaults.removeObject(forKey: Self.communityFollowsKey)
    }

    /// Deletes on-device user data and credentials. No community content is uploaded.
    @discardableResult
    func resetLocalData() -> Bool {
        if isPresentationMode {
            let snapshot = PresentationData.snapshot(llmSettings: llmSettings)
            do {
                try dependencies.storageStore.resetState(snapshot)
                applyAccountSnapshot(snapshot)
                message = "演示数据已恢复。"
                return true
            } catch {
                message = "恢复演示数据失败：\(error.localizedDescription)"
                return false
            }
        }
        guard dependencies.credentialStore.deleteAPIKey() else {
            message = "API Key 无法从系统钥匙串删除，未执行数据重置。"
            return false
        }
        guard imageGenerationReset() else {
            message = "生图 API Key 无法从系统钥匙串删除，未执行数据重置。"
            return false
        }
        // Credential deletion has already succeeded even if a later file operation fails.
        llmSettingsGeneration += 1
        llmSettings.apiKey = ""
        llmSettings.isEnabled = false
        llmSettings.hasCloudConsent = false
        let snapshot = AppStateSnapshot.initial
        do {
            try dependencies.storageStore.resetState(snapshot)
        } catch {
            message = "本地数据重置失败：\(error.localizedDescription)"
            return false
        }
        invalidateScanContext()
        activePlanningID = nil
        isPlanning = false
        storageRecoveryMode = false
        let oldScheduleIDs = scheduleItems.map(\.id)
        spaces = snapshot.spaces
        achievements = snapshot.achievements
        communityCases = snapshot.communityCases
        communityComments = [:]
        likedCommunityCaseIDs = []
        favoriteCommunityCaseIDs = []
        followedCommunityAuthors = []
        scheduleItems = []
        llmSettings = .default
        llmConnectionState = .idle
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
        for key in [Self.communityLikesKey, Self.communityFavoritesKey, Self.communityFollowsKey] {
            defaults.removeObject(forKey: key)
        }
        let identifiers = oldScheduleIDs.map(notificationIdentifier(for:))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
        do {
            try cleanupStoredImages()
            message = "本地数据与 API Key 已清除。"
            return true
        } catch {
            message = "记录与 API Key 已清除，但照片文件删除失败：\(error.localizedDescription)"
            return false
        }
    }

    func resetDemo() { resetLocalData() }

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
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    func showMessage(_ text: String) {
        message = text
    }

    @discardableResult
    func updateLLMSettings(_ settings: LLMSettings) -> Bool {
        if settings.isEnabled, let validationError = llmValidationError(for: settings) {
            llmConnectionState = .failure(validationError)
            message = validationError
            return false
        }
        let normalized = normalizedLLMSettings(settings)
        let previousSettings = llmSettings
        let previousConnectionState = llmConnectionState
        let previousAPIKey = dependencies.credentialStore.loadAPIKey()
        guard dependencies.credentialStore.saveAPIKey(normalized.apiKey) else {
            llmConnectionState = .failure("API Key 无法写入系统钥匙串，请检查设备安全设置。")
            message = "API Key 无法写入系统钥匙串，请检查设备安全设置。"
            return false
        }
        llmSettingsGeneration += 1
        llmSettings = normalized
        llmConnectionState = .idle
        guard persist() else {
            // Keep the keychain and the JSON snapshot in sync when the disk write fails.
            _ = dependencies.credentialStore.saveAPIKey(previousAPIKey ?? "")
            llmSettings = previousSettings
            llmConnectionState = previousConnectionState
            llmSettingsGeneration += 1
            return false
        }
        return true
    }

    @discardableResult
    func saveLLMSettings(_ settings: LLMSettings) -> Bool {
        if settings.isEnabled, let validationError = llmValidationError(for: settings) {
            llmConnectionState = .failure(validationError)
            message = validationError
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

        let previousSettings = llmSettings
        let previousAPIKey = dependencies.credentialStore.loadAPIKey()
        llmSettingsGeneration += 1
        let generation = llmSettingsGeneration
        llmConnectionState = .testing
        do {
            let endpointString = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            let usesChatCompletions = endpointString.lowercased().contains("/chat/completions")
            let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            request.httpBody = usesChatCompletions
                ? try JSONSerialization.data(withJSONObject: [
                    "model": model,
                    "messages": [["role": "user", "content": "Reply with OK."]],
                    "max_tokens": 8
                ])
                : try JSONSerialization.data(withJSONObject: [
                    "model": model,
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
            guard Self.isValidLLMPayload(data, chatCompletions: usesChatCompletions) else {
                let raw = String(data: data, encoding: .utf8) ?? ""
                print("SMARTPAW_LLM_TEST_PARSE_FAIL \(raw.prefix(300))")
                throw LLMConnectionTestError.invalidPayload
            }

            guard generation == llmSettingsGeneration else { return }
            let normalized = normalizedLLMSettings(settings)
            guard dependencies.credentialStore.saveAPIKey(normalized.apiKey) else {
                throw LLMConnectionTestError.keychainWriteFailed
            }
            llmSettings = normalized
            guard persist() else {
                _ = dependencies.credentialStore.saveAPIKey(previousAPIKey ?? "")
                llmSettings = previousSettings
                llmSettingsGeneration += 1
                llmConnectionState = .failure(message ?? "AI 设置无法保存到本地。")
                return
            }
            llmConnectionState = .success("连接成功，Endpoint、API Key 与模型均可用。")
        } catch {
            guard generation == llmSettingsGeneration else { return }
            llmConnectionState = .failure(connectionErrorMessage(for: error))
        }
    }

    func sendChatMessage(message: String, history: [[String: String]], planName: String? = nil) async throws -> String {
        guard llmSettings.canRequest else { throw ChatError.notConfigured }
        let planLine = (planName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            .map { "当前方案：\($0)。用户正在这个方案基础上提微调要求，回答要直接给出怎么改、改哪里。" } ?? ""
        var messages: [[String: String]] = [[
            "role": "system",
            "content": "你是灵爪收纳助手。请基于当前扫描和空间信息，用简洁、具体、可执行的中文回答，控制在 80 字以内。\n\(planLine)\n\(currentChatContext())"
        ]]
        for item in history.prefix(12) {
            guard let role = item["role"], let text = item["text"], !text.isEmpty else { continue }
            messages.append(["role": role == "assistant" ? "assistant" : "user", "content": text])
        }
        messages.append(["role": "user", "content": message])
        return try await requestLLMText(messages: messages, settings: llmSettings, maxTokens: 500)
    }

    /// 统一的文本对话通道：按 Endpoint 自动选择 OpenAI `/responses` 或 `/chat/completions`
    /// （DeepSeek、通义、Kimi、智谱等国产服务都是后者），两种请求体与响应结构并不通用。
    private func requestLLMText(
        messages: [[String: String]],
        settings: LLMSettings,
        maxTokens: Int,
        timeout: TimeInterval = 45
    ) async throws -> String {
        let endpoint = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint) else { throw ChatError.invalidResponse("") }
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let usesChatCompletions = endpoint.lowercased().contains("/chat/completions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if usesChatCompletions {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": model,
                "messages": messages.map { ["role": $0["role"] ?? "user", "content": $0["content"] ?? ""] },
                "max_tokens": maxTokens,
                "temperature": 0.7
            ])
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": model,
                "input": messages.map { ["role": $0["role"] ?? "user", "content": $0["content"] ?? ""] },
                "max_output_tokens": maxTokens
            ])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("SMARTPAW_LLM_HTTP \(http.statusCode) \(raw.prefix(300))")
            throw ChatError.httpFailure(raw)
        }
        if let text = Self.extractLLMText(from: data, chatCompletions: usesChatCompletions), !text.isEmpty {
            return text
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        print("SMARTPAW_LLM_PARSE_FAIL \(raw.prefix(300))")
        throw ChatError.invalidResponse(raw)
    }

    private static func extractLLMText(from data: Data, chatCompletions: Bool) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if chatCompletions {
            guard
                let choices = object["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let text = object["output_text"] as? String, !text.isEmpty { return text }
        guard let output = object["output"] as? [[String: Any]] else { return nil }
        for item in output {
            guard let content = item["content"] as? [[String: Any]] else { continue }
            for part in content where part["type"] as? String == "output_text" {
                if let text = part["text"] as? String, !text.isEmpty { return text }
            }
        }
        return nil
    }

    private func currentChatContext() -> String {
        let space = spaces.first(where: { $0.id == selectedSpaceID })
        let items = (scannedItems.isEmpty ? space?.detectedItems ?? [] : scannedItems)
            .filter(\.isSelected).map { "\($0.name)(\($0.category.rawValue))" }.joined(separator: "、")
        return "空间：\(space?.name ?? "未选择空间")；扫描物品：\(items.isEmpty ? "暂无" : items)；风格：\(selectedStyle.rawValue)；时间预算：\(selectedTimeBudget.title)"
    }

    func llmValidationError(for settings: LLMSettings) -> String? {
        guard settings.hasCloudConsent else { return "请先阅读数据说明并同意将照片和整理信息发送到你配置的 AI 服务。" }
        let endpoint = settings.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.fragment == nil,
              scheme == "https"
        else {
            return "Endpoint 必须是有效的 HTTPS URL。"
        }

        if !settings.visionEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let visionURL = URL(string: settings.resolvedVisionEndpoint.trimmingCharacters(in: .whitespacesAndNewlines))
            guard let visionURL, visionURL.scheme?.lowercased() == "https", let host = visionURL.host, !host.isEmpty,
                  visionURL.user == nil, visionURL.password == nil, visionURL.fragment == nil else {
                return "视觉 Endpoint 必须是有效的 HTTPS URL。"
            }
        }
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.count >= 8, key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "API Key 不能为空、不能包含空格，且长度至少为 8 个字符。"
        }

        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty, model.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "Model 不能为空，也不能包含空格。"
        }
        let visionModel = settings.visionModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard visionModel.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "视觉 Model 不能包含空格。"
        }
        return nil
    }

    @discardableResult
    func toggleScheduleItem(_ id: UUID) -> Bool {
        guard let index = scheduleItems.firstIndex(where: { $0.id == id }) else { return false }
        let previous = scheduleItems
        scheduleItems[index].isDone.toggle()
        let item = scheduleItems[index]
        guard persist() else {
            scheduleItems = previous
            return false
        }
        Task {
            if item.isDone {
                await cancelNotification(for: item.id)
            } else {
                await scheduleNotification(for: item)
            }
        }
        return true
    }

    @discardableResult
    func addScheduleItem(title: String, dueText: String, note: String) -> Bool {
        let migrated = ScheduleItem(title: title, spaceName: selectedSpace.name, dueText: dueText, note: note)
        return addScheduleItem(title: title, dueDate: migrated.dueDate, note: note)
    }

    @discardableResult
    func addScheduleItem(title: String, dueDate: Date, note: String) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        let item = ScheduleItem(
            title: trimmedTitle,
            spaceName: selectedSpace.name,
            dueDate: dueDate,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "复盘本次整理状态" : note
        )
        scheduleItems.insert(item, at: 0)
        guard persist() else {
            scheduleItems.removeAll { $0.id == item.id }
            return false
        }
        Task { await scheduleNotification(for: item) }
        return true
    }

    @discardableResult
    func updateScheduleItem(_ item: ScheduleItem) -> Bool {
        guard let index = scheduleItems.firstIndex(where: { $0.id == item.id }) else { return false }
        var updated = item
        updated.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.title.isEmpty else { return false }
        let previous = scheduleItems[index]
        scheduleItems[index] = updated
        guard persist() else {
            scheduleItems[index] = previous
            return false
        }
        Task {
            await cancelNotification(for: updated.id)
            if !updated.isDone { await scheduleNotification(for: updated) }
        }
        return true
    }

    @discardableResult
    func deleteScheduleItem(_ id: UUID) -> Bool {
        let previous = scheduleItems
        guard previous.contains(where: { $0.id == id }) else { return false }
        scheduleItems.removeAll { $0.id == id }
        guard persist() else {
            scheduleItems = previous
            return false
        }
        Task { await cancelNotification(for: id) }
        return true
    }

    func requestNotificationAuthorization() async {
        guard !isPresentationMode else { return }
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
            model: settings.model.trimmingCharacters(in: .whitespacesAndNewlines),
            visionEndpoint: settings.visionEndpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            visionModel: settings.visionModel.trimmingCharacters(in: .whitespacesAndNewlines),
            hasCloudConsent: settings.hasCloudConsent
        )
    }

    private static func isValidLLMPayload(_ data: Data, chatCompletions: Bool) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if chatCompletions {
            guard let choices = object["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else { return false }
            return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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
        guard !isPresentationMode else { return }
        guard notificationAuthorizationState == .authorized || notificationAuthorizationState == .provisional else { return }
        for item in scheduleItems where !item.isDone && item.dueDate > Date() {
            await scheduleNotification(for: item)
        }
    }

    private func scheduleNotification(for item: ScheduleItem) async {
        guard !isPresentationMode else { return }
        guard !item.isDone, item.dueDate > Date() else {
            await cancelNotification(for: item.id)
            return
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard !isPresentationMode,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
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
        guard !isPresentationMode else { return }
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
        documentsDirectory.appendingPathComponent(isPresentationMode ? "SmartPawPresentationImages" : "SmartPawImages", isDirectory: true)
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

    private func cleanupStoredImages() throws {
        if FileManager.default.fileExists(atPath: imageDirectory.path) {
            try FileManager.default.removeItem(at: imageDirectory)
        }
        let documents = imageDirectory.deletingLastPathComponent()
        for name in ["smartpaw-llm.json", "smartpaw-diagnostics.txt", "smartpaw-selftest.txt"] {
            let url = documents.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }

    private func writeDiagnostics(note: String, items: [DetectedItem]) {
        var lines: [String] = [
            "时间: \(Date())",
            "场景: \(note)",
            "本次物品: \(items.map { "\($0.name)\(Int($0.confidence * 100))%[\($0.category.rawValue)]" }.joined(separator: "、"))",
            "本地模型数: \(YOLOSegmentationScanService.loadedModelCount)",
            "本地模型: \(YOLOSegmentationScanService.loadedModelNames.joined(separator: "、"))",
            "云端开关: \(llmSettings.isEnabled)",
            "云端接口: \(llmSettings.endpoint)",
            "云端模型: \(llmSettings.model)",
            "视觉接口: \(llmSettings.visionEndpoint.isEmpty ? "(复用主接口)" : llmSettings.visionEndpoint)",
            "视觉模型: \(llmSettings.visionModel.isEmpty ? "(复用主模型)" : llmSettings.visionModel)",
            "有密钥: \(!llmSettings.apiKey.isEmpty)",
            "可请求视觉: \(llmSettings.canRequestVision)",
            "本次结果数: \(items.count)",
        ]
        if let router = dependencies.scanService as? RecognitionRouter {
            lines.append("本次明细: \(router.diagnostics)")
        }
        let url = documentsDirectory.appendingPathComponent("smartpaw-diagnostics.txt")
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    @discardableResult
    private func persist() -> Bool {
        guard !storageRecoveryMode else {
            message = "本地数据处于恢复模式，原文件已保留；请先恢复备份或清除本地数据。"
            return false
        }
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
            return true
        } catch {
            message = "保存失败：\(error.localizedDescription)"
            return false
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

    private static func loadCommunityIDs(forKey key: String, defaults: UserDefaults) -> Set<UUID> {
        Set((defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:)))
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
