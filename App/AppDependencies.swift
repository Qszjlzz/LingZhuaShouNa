import Foundation

struct AppDependencies {
    let scanService: ScanService
    let planningService: PlanningService
    let cloudPlanningService: CloudPlanningService
    let storageStore: StorageStore
    let credentialStore: CredentialStore

    static let live = AppDependencies(
        scanService: RecognitionRouter.shared,
        planningService: RuleBasedPlanningService(),
        cloudPlanningService: OpenAICompatiblePlanningService(),
        storageStore: PresentationStorageStore.live(),
        credentialStore: SystemCredentialStore()
    )

    static let preview = AppDependencies(
        scanService: RecognitionRouter.shared,
        planningService: RuleBasedPlanningService(),
        cloudPlanningService: OpenAICompatiblePlanningService(),
        storageStore: InMemoryStorageStore(),
        credentialStore: SystemCredentialStore()
    )
}

/// The presentation account keeps its mutations separate from the user's account.
final class PresentationStorageStore: StorageStore {
    private let realStore: StorageStore
    private let presentationStore: StorageStore
    private let defaults: UserDefaults
    private let modeKey: String
    private(set) var isPresentationMode: Bool

    init(realStore: StorageStore, presentationStore: StorageStore, defaults: UserDefaults = .standard,
         modeKey: String = "SmartPaw.presentationMode", initialMode: Bool = false) {
        self.realStore = realStore
        self.presentationStore = presentationStore
        self.defaults = defaults
        self.modeKey = modeKey
        isPresentationMode = defaults.object(forKey: modeKey) == nil ? initialMode : defaults.bool(forKey: modeKey)
    }

    static func live() -> PresentationStorageStore {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #if DEBUG
        let initialMode = true
        #else
        let initialMode = false
        #endif
        return PresentationStorageStore(
            realStore: JSONStorageStore(),
            presentationStore: JSONStorageStore(stateURL: documents.appendingPathComponent("smart-paw-presentation-state.json")),
            initialMode: initialMode
        )
    }

    func loadState() throws -> AppStateSnapshot? {
        if isPresentationMode { return try overlaySharedSettings(on: loadPresentationState()) }
        return try overlaySharedSettings(on: realStore.loadState() ?? .initial)
    }

    func saveState(_ snapshot: AppStateSnapshot) throws {
        try activeStore.saveState(snapshot)
        saveSharedSettings(snapshot.llmSettings)
    }

    func resetState(_ snapshot: AppStateSnapshot) throws {
        try activeStore.resetState(snapshot)
        saveSharedSettings(snapshot.llmSettings)
    }

    /// Read and initialize the destination before changing the selected account.
    func setPresentationMode(_ enabled: Bool) throws -> AppStateSnapshot {
        let destination: AppStateSnapshot
        if enabled {
            destination = try loadPresentationState()
        } else {
            destination = try realStore.loadState() ?? .initial
        }
        let snapshot = try overlaySharedSettings(on: destination)
        isPresentationMode = enabled
        defaults.set(enabled, forKey: modeKey)
        return snapshot
    }

    private var activeStore: StorageStore { isPresentationMode ? presentationStore : realStore }
    private var settingsKey: String { "\(modeKey).sharedLLMSettings" }

    private func loadPresentationState() throws -> AppStateSnapshot {
        if let snapshot = try presentationStore.loadState() {
            let migrated = migratePresentationCategories(snapshot)
            if migrated != snapshot { try presentationStore.saveState(migrated) }
            return migrated
        }
        let settings = try realStore.loadState()?.llmSettings ?? .default
        let snapshot = PresentationData.snapshot(llmSettings: settings)
        try presentationStore.saveState(snapshot)
        return snapshot
    }

    private func migratePresentationCategories(_ snapshot: AppStateSnapshot) -> AppStateSnapshot {
        let categories = Dictionary(uniqueKeysWithValues: PresentationData.snapshot().spaces
            .flatMap(\.detectedItems)
            .filter { $0.category == .tools || $0.category == .decor }
            .map { ($0.id, $0.category) })
        var migrated = snapshot
        func update(_ items: inout [DetectedItem]) {
            for index in items.indices {
                guard items[index].category == .electronics || items[index].category == .stationery,
                      let category = categories[items[index].id] else { continue }
                items[index].category = category
            }
        }
        for index in migrated.spaces.indices { update(&migrated.spaces[index].detectedItems) }
        for index in migrated.communityCases.indices { update(&migrated.communityCases[index].items) }
        return migrated
    }

    private func overlaySharedSettings(on snapshot: AppStateSnapshot) throws -> AppStateSnapshot {
        var snapshot = snapshot
        if let data = defaults.data(forKey: settingsKey) {
            snapshot.llmSettings = try JSONDecoder().decode(LLMSettings.self, from: data)
        } else {
            let settings = try realStore.loadState()?.llmSettings ?? snapshot.llmSettings
            saveSharedSettings(settings)
            snapshot.llmSettings = settings
        }
        return snapshot
    }

    private func saveSharedSettings(_ settings: LLMSettings) {
        var safeSettings = settings
        safeSettings.apiKey = ""
        if let data = try? JSONEncoder().encode(safeSettings) { defaults.set(data, forKey: settingsKey) }
    }
}
