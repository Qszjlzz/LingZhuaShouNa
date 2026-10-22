import XCTest
import UIKit
@testable import SmartPaw

final class PresentationModeTests: XCTestCase {
    func testPresentationMutationsAndModeSurviveReopeningWithoutChangingRealFile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let realURL = directory.appendingPathComponent("real.json")
        let demoURL = directory.appendingPathComponent("presentation.json")
        let real = JSONStorageStore(stateURL: realURL, credentialStore: PresentationCredentialStore())
        let demo = JSONStorageStore(stateURL: demoURL, credentialStore: PresentationCredentialStore())
        var original = AppStateSnapshot.initial
        original.spaces[0].name = "我的真实书房"
        try real.saveState(original)
        let originalBytes = try Data(contentsOf: realURL)
        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults, initialMode: true)
        var presentation = try XCTUnwrap(store.loadState())
        presentation.spaces[0].name = "改名后的演示卧室"
        try store.saveState(presentation)
        XCTAssertEqual(try Data(contentsOf: realURL), originalBytes)
        XCTAssertEqual(try store.setPresentationMode(false).spaces[0].name, "我的真实书房")
        let reopened = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults, initialMode: true)
        XCTAssertFalse(reopened.isPresentationMode)
        XCTAssertEqual(try reopened.setPresentationMode(true).spaces[0].name, "改名后的演示卧室")
        XCTAssertEqual(try Data(contentsOf: realURL), originalBytes)
    }

    func testFailedDestinationReadOrSeedWriteKeepsCurrentAccount() throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let real = PresentationTestStorage(snapshot: .initial)
        let demo = PresentationTestStorage()
        demo.failWrite = true
        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults)
        XCTAssertThrowsError(try store.setPresentationMode(true))
        XCTAssertFalse(store.isPresentationMode)
        XCTAssertNil(defaults.object(forKey: "SmartPaw.presentationMode"))
        demo.failWrite = false
        _ = try store.setPresentationMode(true)
        real.failRead = true
        XCTAssertThrowsError(try store.setPresentationMode(false))
        XCTAssertTrue(store.isPresentationMode)
        XCTAssertTrue(defaults.bool(forKey: "SmartPaw.presentationMode"))
    }

    func testLegacyPresentationCategoriesMigrateWithoutReplacingEditsOrRealData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let credentials = PresentationCredentialStore(key: "preserved-key")
        let realURL = directory.appendingPathComponent("real.json")
        let demoURL = directory.appendingPathComponent("presentation.json")
        let real = JSONStorageStore(stateURL: realURL, credentialStore: credentials)
        let demo = JSONStorageStore(stateURL: demoURL, credentialStore: credentials)
        var legacy = PresentationData.snapshot(now: Date(timeIntervalSince1970: 1_700_000_000))
        legacy.spaces[2].name = "保留的空间名"
        legacy.spaces[2].detectedItems[0].category = .electronics
        legacy.spaces[2].detectedItems[0].name = "保留的物品名"
        legacy.spaces[2].detectedItems[0].suggestedZone = "保留的分组"
        legacy.spaces[2].detectedItems[6].category = .stationery
        legacy.spaces[2].detectedItems[22].category = .stationery
        legacy.spaces[2].detectedItems[1].category = .health
        let addedItem = DetectedItem(name: "用户新增文具", category: .stationery, confidence: 1)
        legacy.spaces[2].detectedItems.append(addedItem)
        legacy.spaces[0].detectedItems.removeLast()
        legacy.spaces[2].activePlan?.isPaused = true
        legacy.scheduleItems.removeAll()
        legacy.communityCases[2].items[0].category = .electronics
        try real.saveState(legacy)
        try demo.saveState(legacy)
        let originalRealBytes = try Data(contentsOf: realURL)
        var expected = legacy
        expected.spaces[2].detectedItems[0].category = .tools
        expected.spaces[2].detectedItems[6].category = .tools
        expected.spaces[2].detectedItems[22].category = .decor
        expected.communityCases[2].items[0].category = .tools

        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults)
        let migrated = try store.setPresentationMode(true)
        XCTAssertEqual(migrated, expected)
        XCTAssertEqual(try demo.loadState(), expected)
        XCTAssertEqual(try Data(contentsOf: realURL), originalRealBytes)
        XCTAssertEqual(try store.setPresentationMode(false), legacy)
        XCTAssertEqual(credentials.key, "preserved-key")
        XCTAssertEqual(credentials.writeCount, 0)
        XCTAssertEqual(credentials.deleteCount, 0)
    }

    func testLegacyPresentationMigrationWritesOnceAndFailureKeepsRealMode() throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        var legacy = PresentationData.snapshot()
        legacy.spaces[2].detectedItems[0].category = .electronics
        let real = PresentationTestStorage(snapshot: .initial)
        let demo = PresentationTestStorage(snapshot: legacy)
        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults)
        demo.failWrite = true
        XCTAssertThrowsError(try store.setPresentationMode(true))
        XCTAssertFalse(store.isPresentationMode)
        XCTAssertNil(defaults.object(forKey: "SmartPaw.presentationMode"))
        XCTAssertEqual(demo.snapshot, legacy)
        demo.failWrite = false
        let migrated = try store.setPresentationMode(true)
        XCTAssertEqual(migrated.spaces[2].detectedItems[0].category, .tools)
        XCTAssertEqual(demo.saveCount, 1)
        XCTAssertEqual(try store.loadState(), migrated)
        XCTAssertEqual(demo.saveCount, 1)
        XCTAssertEqual(real.saveCount, 0)
    }

    func testLLMMetadataIsSharedAcrossAccountsAndReopeningWithoutPersistingKey() throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        var initial = AppStateSnapshot.initial
        initial.llmSettings = LLMSettings(isEnabled: true, endpoint: "https://first.example/v1/responses",
                                          apiKey: "", model: "first-model", hasCloudConsent: true)
        let real = PresentationTestStorage(snapshot: initial)
        let demo = PresentationTestStorage()
        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults, initialMode: true)
        var snapshot = try XCTUnwrap(store.loadState())
        XCTAssertEqual(snapshot.llmSettings.endpoint, initial.llmSettings.endpoint)
        snapshot.llmSettings = LLMSettings(isEnabled: true, endpoint: "https://second.example/v1/responses",
                                           apiKey: "key-must-stay-in-keychain", model: "second-model", hasCloudConsent: true)
        demo.failWrite = true
        XCTAssertThrowsError(try store.saveState(snapshot))
        XCTAssertEqual(try store.loadState()?.llmSettings.endpoint, initial.llmSettings.endpoint)
        demo.failWrite = false
        try store.saveState(snapshot)
        let sharedData = try XCTUnwrap(defaults.data(forKey: "SmartPaw.presentationMode.sharedLLMSettings"))
        let shared = try JSONSerialization.jsonObject(with: sharedData) as? [String: Any]
        XCTAssertNil(shared?["apiKey"])
        XCTAssertFalse(String(data: sharedData, encoding: .utf8)!.contains("key-must-stay-in-keychain"))
        XCTAssertEqual(try store.setPresentationMode(false).llmSettings.endpoint, snapshot.llmSettings.endpoint)
        XCTAssertEqual(real.snapshot, initial)
        let reopened = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults, initialMode: true)
        XCTAssertEqual(try reopened.loadState()?.llmSettings.model, "second-model")
        XCTAssertEqual(try reopened.setPresentationMode(true).llmSettings.endpoint, snapshot.llmSettings.endpoint)
        XCTAssertEqual(real.snapshot, initial)
    }

    @MainActor
    func testSwitchClearsScanStatePreservesCredentialsAndKeepsEditsInTheirAccount() throws {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let real = PresentationTestStorage(snapshot: .initial)
        let demo = PresentationTestStorage()
        let store = PresentationStorageStore(realStore: real, presentationStore: demo, defaults: defaults, initialMode: true)
        let credentials = PresentationCredentialStore(key: "fixture-key")
        let model = AppViewModel(dependencies: dependencies(store: store, credentials: credentials))
        XCTAssertTrue(model.isPresentationMode)
        XCTAssertEqual(model.catalogItems.count, 64)
        let space = model.spaces[0]
        XCTAssertTrue(model.renameSpace(space.id, name: "演示卧室"))
        model.beginPhotoScanSession()
        model.scannedItems = [DetectedItem(name: "临时识别", category: .books, confidence: 1)]
        model.capturedImage = UIImage()
        model.referenceImage = UIImage()
        XCTAssertTrue(model.setPresentationMode(false))
        XCTAssertTrue(model.scannedItems.isEmpty)
        XCTAssertNil(model.capturedImage)
        XCTAssertNil(model.referenceImage)
        XCTAssertEqual(model.spaces[0].name, "我的空间")
        XCTAssertEqual(credentials.key, "fixture-key")
        XCTAssertEqual(credentials.writeCount, 0)
        XCTAssertEqual(credentials.deleteCount, 0)
        model.cancelScanWork()
        XCTAssertEqual(model.spaces[0].name, "我的空间")
        XCTAssertTrue(model.setPresentationMode(true))
        XCTAssertEqual(model.spaces[0].name, "演示卧室")
        XCTAssertTrue(model.resetLocalData())
        XCTAssertEqual(model.catalogItems.count, 64)
        XCTAssertEqual(real.snapshot?.spaces[0].name, "我的空间")
        XCTAssertEqual(credentials.deleteCount, 0)
    }

    @MainActor
    func testOrdinaryInjectedDependenciesKeepEmptyRealAccount() {
        let model = AppViewModel(dependencies: dependencies(store: PresentationTestStorage(), credentials: PresentationCredentialStore()))
        XCTAssertFalse(model.isPresentationMode)
        XCTAssertEqual(model.catalogItems.count, 0)
    }

    @MainActor
    func testPresentationDoesNotConsumeLegacyRealFavorites() {
        let defaults = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let legacyKey = "SmartPaw.community.favoriteCaseIDs"
        let legacyKeys = [legacyKey, "SmartPaw.community.likedCaseIDs", "SmartPaw.community.followedAuthors"]
        let previous = legacyKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(legacyKeys, previous) {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        let legacyID = UUID()
        UserDefaults.standard.set([legacyID.uuidString], forKey: legacyKey)
        let store = PresentationStorageStore(realStore: PresentationTestStorage(snapshot: .initial),
                                            presentationStore: PresentationTestStorage(), defaults: defaults, initialMode: true)
        let model = AppViewModel(dependencies: dependencies(store: store, credentials: PresentationCredentialStore()))
        XCTAssertFalse(model.favoriteCommunityCaseIDs.contains(legacyID))
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: legacyKey), [legacyID.uuidString])
        XCTAssertTrue(model.setPresentationMode(false))
        XCTAssertTrue(model.favoriteCommunityCaseIDs.contains(legacyID))
        XCTAssertNil(UserDefaults.standard.object(forKey: legacyKey))
    }

    func testPresentationFixtureHasConsistentReferencesAndEveryVisibleState() {
        let snapshot = PresentationData.snapshot(now: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(snapshot.spaces.map { $0.detectedItems.count }, [24, 9, 31])
        XCTAssertEqual(Set(snapshot.spaces.flatMap(\.detectedItems).map(\.category)).count, 8)
        XCTAssertEqual(snapshot.spaces.compactMap(\.activePlan).count, 3)
        XCTAssertEqual(snapshot.spaces.flatMap(\.completedPlans).count, 3)
        XCTAssertEqual(snapshot.scheduleItems.count, 1)
        XCTAssertEqual(snapshot.spaces[0].activePlan?.steps.filter { $0.status == .done }.count, 7)
        XCTAssertEqual(snapshot.spaces[0].activePlan?.steps.count, 20)
        XCTAssertEqual(snapshot.spaces[1].activePlan?.isPaused, true)
        XCTAssertEqual(snapshot.spaces[1].activePlan?.steps.filter { $0.status == .done }.count, 3)
        for space in snapshot.spaces {
            let itemIDs = Set(space.detectedItems.map(\.id))
            for plan in [space.activePlan].compactMap({ $0 }) + space.completedPlans {
                XCTAssertTrue(plan.steps.allSatisfy { Set($0.itemIDs).isSubset(of: itemIDs) })
                XCTAssertLessThanOrEqual(plan.steps.filter { $0.status == .active }.count, 1)
            }
        }
        XCTAssertTrue(snapshot.favoriteCommunityCaseIDs.isSubset(of: Set(snapshot.communityCases.map(\.id))))
        let groups = Set(snapshot.spaces.flatMap(\.detectedItems).filter { $0.category == .books }.map(\.suggestedZone))
        XCTAssertEqual(groups, ["小说", "学习", "哲学"])
    }

    private let defaultsSuite = "SmartPaw.PresentationTests.\(UUID().uuidString)"
    private func isolatedDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defaults.removePersistentDomain(forName: defaultsSuite)
        return defaults
    }

    private func dependencies(store: StorageStore, credentials: CredentialStore) -> AppDependencies {
        AppDependencies(scanService: PresentationScanService(), planningService: RuleBasedPlanningService(),
                        cloudPlanningService: PresentationPlanningService(), storageStore: store, credentialStore: credentials)
    }
}

private final class PresentationTestStorage: StorageStore {
    var snapshot: AppStateSnapshot?
    var failRead = false
    var failWrite = false
    var saveCount = 0
    init(snapshot: AppStateSnapshot? = nil) { self.snapshot = snapshot }
    func loadState() throws -> AppStateSnapshot? {
        if failRead { throw CocoaError(.fileReadUnknown) }
        return snapshot
    }
    func saveState(_ snapshot: AppStateSnapshot) throws {
        if failWrite { throw CocoaError(.fileWriteUnknown) }
        self.snapshot = snapshot
        saveCount += 1
    }
}

private final class PresentationCredentialStore: CredentialStore {
    var key: String?
    var writeCount = 0
    var deleteCount = 0
    init(key: String? = nil) { self.key = key }
    func loadAPIKey() -> String? { key }
    func saveAPIKey(_ key: String) -> Bool { self.key = key; writeCount += 1; return true }
    func deleteAPIKey() -> Bool { key = nil; deleteCount += 1; return true }
}

private struct PresentationScanService: ScanService {
    func scanImage(_ image: UIImage) async throws -> [DetectedItem] { [] }
}

private struct PresentationPlanningService: CloudPlanningService {
    func refine(plan: StoragePlan, context: PlanningContext, settings: LLMSettings) async throws -> StoragePlan { plan }
}
