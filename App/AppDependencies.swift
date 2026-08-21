import Foundation

struct AppDependencies {
    let scanService: ScanService
    let planningService: PlanningService
    let cloudPlanningService: CloudPlanningService
    let storageStore: StorageStore
    let credentialStore: CredentialStore

    static let live = AppDependencies(
        scanService: YOLOSegmentationScanService(),
        planningService: RuleBasedPlanningService(),
        cloudPlanningService: OpenAICompatiblePlanningService(),
        storageStore: JSONStorageStore(),
        credentialStore: SystemCredentialStore()
    )

    static let preview = AppDependencies(
        scanService: YOLOSegmentationScanService(),
        planningService: RuleBasedPlanningService(),
        cloudPlanningService: OpenAICompatiblePlanningService(),
        storageStore: InMemoryStorageStore(),
        credentialStore: SystemCredentialStore()
    )
}
