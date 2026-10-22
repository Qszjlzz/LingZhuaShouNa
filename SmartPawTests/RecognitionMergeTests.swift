import UIKit
import XCTest
@testable import SmartPaw

final class RecognitionMergeTests: XCTestCase {
    private var visionSettings: LLMSettings {
        LLMSettings(isEnabled: true, endpoint: "https://example.com/v1/responses", apiKey: "test-only",
                    model: "vision-test", hasCloudConsent: true)
    }

    func testCloudSuccessDoesNotRunLocalOrAppendFalsePositives() async throws {
        var localCalls = 0
        let expected = DetectedItem(name: "平板电脑", category: .electronics, confidence: 0.9)
        let router = RecognitionRouter(localScan: { _ in
            localCalls += 1
            return [DetectedItem(name: "遥控器", category: .electronics, confidence: 0.95)]
        }, cloudScan: { _, _ in [expected] })
        router.settingsProvider = { self.visionSettings }
        let result = try await router.scanImage(UIImage())
        XCTAssertEqual(result, [expected])
        XCTAssertEqual(localCalls, 0)
        XCTAssertEqual(router.diagnostics["source"], "大模型")
    }

    func testValidEmptyCloudSceneDoesNotInventLocalObjects() async throws {
        var localCalls = 0
        let router = RecognitionRouter(localScan: { _ in
            localCalls += 1
            return [DetectedItem(name: "杯子", category: .drinks, confidence: 0.9)]
        }, cloudScan: { _, _ in [] })
        router.settingsProvider = { self.visionSettings }
        let result = try await router.scanImage(UIImage())
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(localCalls, 0)
    }

    func testCloudFailureFallsBackAndPreservesFailureDiagnostic() async throws {
        let local = DetectedItem(name: "杯子", category: .drinks, confidence: 0.8)
        let router = RecognitionRouter(localScan: { _ in [local] }, cloudScan: { _, _ in
            throw CloudVisionError.transport("HTTP 429")
        })
        router.settingsProvider = { self.visionSettings }
        let result = try await router.scanImage(UIImage())
        XCTAssertEqual(result, [local])
        XCTAssertEqual(router.diagnostics["source"], "本地降级")
        XCTAssertTrue(router.diagnostics["云端错误"]?.contains("429") == true)
    }

    func testEveryPhotoCanUseCloudAndCancellationDoesNotFallback() async throws {
        var calls = 0
        let router = RecognitionRouter(localScan: { _ in XCTFail("Local must not run"); return [] }, cloudScan: { _, _ in
            calls += 1
            return [DetectedItem(name: "笔", category: .stationery, confidence: 0.9)]
        })
        router.settingsProvider = { self.visionSettings }
        _ = try await router.scanImage(UIImage())
        _ = try await router.scanImage(UIImage())
        XCTAssertEqual(calls, 2)
        let cancelled = RecognitionRouter(localScan: { _ in XCTFail("Cancellation must not fallback"); return [] },
                                          cloudScan: { _, _ in throw CancellationError() })
        cancelled.settingsProvider = { self.visionSettings }
        do { _ = try await cancelled.scanImage(UIImage()); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testNoConsentDoesNotUploadPhotos() async throws {
        let router = RecognitionRouter(localScan: { _ in [] }, cloudScan: { _, _ in
            XCTFail("No consent must never upload"); return []
        })
        router.settingsProvider = { .default }
        _ = try await router.scanImage(UIImage())
        XCTAssertEqual(router.diagnostics["云端已配置"], "否")
    }

    @MainActor
    func testSameNamedInstancesRemainSeparateAndStableIDUpdatesOnlyOnce() {
        let first = DetectedItem(name: "杯子", category: .drinks, confidence: 0.8)
        let second = DetectedItem(name: "杯子", category: .drinks, confidence: 0.9)
        var updated = first
        updated.name = "马克杯"
        let merged = AppViewModel.merging([first, second], with: [updated])
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.map(\.id), [first.id, second.id])
        XCTAssertEqual(merged.map(\.name), ["马克杯", "杯子"])
    }

    func testShortPlansIncludeEverySelectedItemWithoutInventingCompositeARAnchor() {
        let items = ItemCategory.allCases.map { DetectedItem(name: $0.rawValue + "测试物品", category: $0, confidence: 0.9,
                                                            arHint: ARHint(x: 0.5, y: 0.5, width: 0.1, height: 0.1)) }
        let excluded = DetectedItem(name: "未选择", category: .tools, confidence: 0.9, isSelected: false)
        let space = StorageSpace(name: "覆盖检查", subtitle: "", beforeImageName: "", afterImageName: "", detectedItems: items)
        for budget in [TimeBudget.five, .ten, .sixty] {
            let plan = RuleBasedPlanningService().makePlan(for: space, selectedItems: items + [excluded], style: .quickReset, timeBudget: budget)
            XCTAssertEqual(Set(plan.steps.flatMap(\.itemIDs)), Set(items.map(\.id)))
            XCTAssertEqual(plan.steps.flatMap(\.itemIDs).count, items.count)
            for item in items { XCTAssertTrue(plan.steps.contains { $0.detail.contains(item.name) }) }
            XCTAssertFalse(plan.steps.flatMap(\.itemIDs).contains(excluded.id))
            if budget != .sixty {
                XCTAssertEqual(plan.steps.count, budget == .five ? 2 : 3)
                XCTAssertNil(plan.steps.last?.arHint, "A composite action must not borrow one item's location for every category.")
            }
        }
    }

    func testLocalPhotoPresentationPreservesSeparateBooksAndRelaxedSameNameInstances() {
        let items = (0..<18).map { index in
            DetectedItem(name: "书本/资料", category: .books, confidence: 0.8,
                         arHint: ARHint(x: 0.05 + Double(index % 6) * 0.16, y: 0.12 + Double(index / 6) * 0.3,
                                        width: 0.08, height: 0.12))
        }
        XCTAssertEqual(YOLOSegmentationScanService.photoPresentationItems(items).count, 18)
        XCTAssertEqual(YOLOSegmentationScanService.relaxedItems(items).count, 18)
        XCTAssertEqual(YOLOSegmentationScanService.relaxedItems(items, limit: 6).count, 6)
        let duplicate = DetectedItem(name: items[0].name, category: items[0].category,
                                     confidence: items[0].confidence, arHint: items[0].arHint)
        XCTAssertEqual(YOLOSegmentationScanService.relaxedItems(items + [duplicate]).count, 18)
    }

    func testStillPhotoPreservesMoreThanTwelveDetectedPossessions() {
        let local = (0..<18).map {
            DetectedItem(name: "物品\($0)", category: .tools, confidence: 0.8)
        }
        var report: [String: String] = [:]
        let result = RecognitionRouter.combine(local: local, cloud: [], live: false) { report = $0 }
        XCTAssertEqual(result.map(\.id), local.map(\.id))
        XCTAssertEqual(report["返回"], "18")
        XCTAssertEqual(report["截断"], "0")
    }

    func testLiveOverlayStillHasABoundedCandidateCount() {
        let local = (0..<18).map {
            DetectedItem(name: "物品\($0)", category: .tools, confidence: 0.8)
        }
        let result = RecognitionRouter.combine(local: local, cloud: [], live: true) { _ in }
        XCTAssertEqual(result.count, 8)
    }

    func testSameNamedObjectsAtSeparatePositionsDoNotExchangeMasks() throws {
        let left = ARHint(x: 0.15, y: 0.4, width: 0.1, height: 0.2)
        let right = ARHint(x: 0.85, y: 0.4, width: 0.1, height: 0.2)
        let local = DetectedItem(name: "杯子", category: .drinks, confidence: 0.8, arHint: left)
        let cloud = DetectedItem(name: "杯子", category: .drinks, confidence: 0.9, arHint: right)
        let result = RecognitionRouter.combine(local: [local], cloud: [cloud], live: false) { _ in }
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first?.arHint, right)
        XCTAssertEqual(result.last?.arHint, left)
    }

    func testOverlappingObjectsKeepTheLocalOutlineAndCloudName() {
        let hint = ARHint(x: 0.4, y: 0.5, width: 0.2, height: 0.2)
        let outline = ARMask(points: [ARMaskPoint(x: 0.3, y: 0.4), ARMaskPoint(x: 0.5, y: 0.6)])
        let local = DetectedItem(name: "book", category: .books, confidence: 0.8, arHint: hint, arMask: outline)
        let cloud = DetectedItem(name: "笔记本", category: .books, confidence: 0.9, arHint: hint)
        let result = RecognitionRouter.combine(local: [local], cloud: [cloud], live: false) { _ in }
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "笔记本")
        XCTAssertEqual(result.first?.arMask, outline)
    }
}
