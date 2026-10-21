# 本地识别验证记录

验证日期：2026-10-20。环境：Xcode 16.4 / iOS 18.5 Simulator，iPhone 16 模拟器 `FA63A134-783E-4983-A62C-08CA35AF70F8`。

## 当前结论

“照片没有识别结果时仍可手动整理并完成本地流程”已通过独立回归。最后一次功能回归执行 50 个测试，0 失败，随后追加的识别取消回归 1 个测试通过；“对所有房间、衣柜和车库杂物都能稳定识别并定位”尚未达到现有精度门槛。全量测试有失败，不能把只覆盖数据与交互逻辑的通过结果表述为全量通过或识别验收通过。

原有图像精度测试仍保留在 `SmartPawTests` 类中，原有图像数量、召回、遮罩和 AR 定位断言没有删除、放宽或迁移。以下功能回归的排除项只是用于单独检查其他修复，不替代这些门槛。

## 已修正的问题

- 模拟器执行系统 Vision 时，默认计算后端曾报 `Failed to create espresso context`。模拟器现在按 Vision 实际支持的计算阶段选择 CPU，Core ML 分割的模拟器配置也使用 CPU。真机继续使用原有设备选择策略。
- Vision 对整张室内照片曾给出 `outdoor` 场景分类。此类全局分类没有可核对的物品和位置，已删除将任意最高场景分类转换为用户物品的兜底。无法识别时允许真实空结果。
- 手工添加物品不再因为缺少照片坐标而被收纳规划丢弃，也不会生成虚构 AR 坐标。识别失败后可以手动添加物品、生成步骤、逐步完成、拍摄整理后照片并在重启后恢复成果。
- 手动补录、确认识别列表、创建方案和完成步骤在保存失败时返回失败，并恢复此前空间、识别列表、执行分区和页面状态。云端优化前必须先成功保存本地方案；云端结果保存失败时保留已落盘的本地方案。失败写盘测试验证了错误返回、原记录保留、重试成功与重启恢复。
- 识别工作取消或网页销毁时可调用 `cancelScanWork()` 使当前识别上下文失效；单张和批量扫描在异步结果返回后同时检查任务取消状态，避免晚到结果再次写入。

## 实际结果

| 验证 | 结果与限制 | 本机日志 |
| --- | --- | --- |
| 修复前全量测试 | 执行 54 个测试，共 21 次断言失败；既包括后续已修复的规划问题，也包括未达标的模型精度。此记录不能代表最新代码全部通过。 | `/tmp/smartpaw-tests.log` |
| YOLO 十场景评测（上述全量运行） | 场景命中率 80%，可用遮罩场景率 80%，平均 3.7 个候选；杂乱房间与车库没有候选。现有评测测试失败。 | 同上，`SMARTPAW_EVAL_SUMMARY` |
| YOLO 物品级评测（上述全量运行） | 6 张照片、16 个标注目标，匹配 11 个，遗漏 5 个，另有 7 个未匹配候选；目标召回率 69%，匹配目标平均 IoU 0.643。车库工具和衣柜目标遗漏。现有评测测试失败。 | 同上，`SMARTPAW_OBJECT_EVAL_SUMMARY` |
| 独立照片数量门槛（上述全量运行） | 书桌照片得到 4 个遮罩，低于原测试要求的 8 个；杂乱房间无候选，低于要求的至少 1 个。 | 同上，`testYOLOSegmentationModelRecognizesNewNonVideoImages` |
| CPU 配置后窄测 | DeepLab 分割及真实规划锚点测试通过；两个 Vision 真实照片测试仍因缺少 AR 区域失败。当时尚未删除最高场景分类兜底。 | `/tmp/smartpaw-recognition-cpu2.log` |
| 最后一次识别边界窄测 | 4 个测试通过：不将场景标签存为物品、未识别照片的手动完整本地流程、生成文字 OCR 映射、保留真实 AR 锚点。`xcodebuild` 返回 0 并输出 `TEST SUCCEEDED`；Xcode 写入 xcresult 时另报 `mkstemp` / CASDB 错误，因此以文本日志为本次证据。 | `/tmp/smartpaw-recognition-boundary.log` |
| 最后一次功能回归 | 按下方明确排除 14 个模型相关测试的命令执行 50 个测试，0 失败，含失败写盘的重试及云端返回后保存失败回归；`xcodebuild` 返回 0 / `TEST SUCCEEDED`。结果包完整，可由 `xcresulttool` 读取为 `Passed`，并核实运行设备是 FA63 iPhone 16 模拟器。 | `/tmp/smartpaw-functional-final.log` |
| 识别取消追加回归 | 1 个测试通过，内部覆盖单张/批量扫描与 Task 取消/上下文取消的四种组合，均不会写入晚到结果；`xcodebuild` 返回 0 / `TEST SUCCEEDED`。测试初次因未固定初始快照的随机 UUID 而失败，修正测试存储初始化后复跑通过。 | `/tmp/smartpaw-scan-cancel-final.log` |

最后一次窄测命令：

```sh
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw \
  -destination 'platform=iOS Simulator,id=FA63A134-783E-4983-A62C-08CA35AF70F8' \
  -derivedDataPath /tmp/smartpaw-recognition-tests \
  -parallel-testing-enabled NO \
  -only-testing:SmartPawTests/SmartPawTests/testVisionFallbackDoesNotPresentSceneLabelsAsPossessions \
  -only-testing:SmartPawTests/SmartPawTests/testUnrecognizedPhotoSupportsManualEntryAndACompleteLocalPlan \
  -only-testing:SmartPawTests/SmartPawTests/testVisionScanServiceMapsGeneratedOCRTextOnly \
  -only-testing:SmartPawTests/SmartPawTests/testPlanningServiceUsesRecognizedARHintsForGuideSteps \
  test CODE_SIGNING_ALLOWED=NO
```

原计划结果目录为 `/tmp/smartpaw-recognition-tests/Logs/Test/Test-SmartPaw-2026.10.20_00-41-02-+0800.xcresult`，本次写入不完整，不能将其作为可打开的完整结果包交付。

## 单独运行功能回归

以下命令显式跳过 14 个模型资源或真实照片精度测试；会保留 OCR、类别映射、遮罩数学、空识别人工流程以及数据、规划、隐私同意和重置回归。报告该命令时应写“功能回归”，不能写“全量测试”。

已于 2026-10-20 00:59 执行此命令，50 个测试全部通过。完整结果包：`/tmp/smartpaw-functional-tests/Logs/Test/Test-SmartPaw-2026.10.20_00-59-02-+0800.xcresult`。`xcresulttool get test-results summary` 确认 `totalTestCount: 50`、`passedTests: 50`、`failedTests: 0`、`result: Passed`；被命令排除的模型测试未进入本次执行计数。此运行早于追加取消测试，取消测试另有完整结果包 `/tmp/smartpaw-functional-tests/Logs/Test/Test-SmartPaw-2026.10.20_01-01-05-+0800.xcresult`，不是把两次执行合称一次 51 项回归。

随后在扫描确认后取消回滚修复后，使用同一排除范围重新执行当前工作区，得到 53/53 通过；最新结果包为 `/tmp/SmartPawFunctionalLatest/Logs/Test/Test-SmartPaw-2026.10.20_13-23-25-+0800.xcresult`，机器可读摘要见 `evidence/functional-recheck-2026-10-20.json`。该数字仍是功能回归，不包含下列 14 项模型资源或真实图片精度测试。

```sh
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw \
  -destination 'platform=iOS Simulator,id=FA63A134-783E-4983-A62C-08CA35AF70F8' \
  -derivedDataPath /tmp/smartpaw-functional-tests \
  -parallel-testing-enabled NO \
  -skip-testing:SmartPawTests/SmartPawTests/testMobileCLIPResourcesLoadAndEncodeText \
  -skip-testing:SmartPawTests/SmartPawTests/testSemanticRecognitionRunsMobileCLIPOnBundledDeskPhoto \
  -skip-testing:SmartPawTests/SmartPawTests/testMobileCLIPEvaluationDatasetReportsSemanticBaseline \
  -skip-testing:SmartPawTests/SmartPawTests/testVisionScanServiceScansBundledIndependentPhotoWithARHints \
  -skip-testing:SmartPawTests/SmartPawTests/testVisionScanServiceBuildsBaselineForIndependentPhotos \
  -skip-testing:SmartPawTests/SmartPawTests/testBundledCoreMLSegmentationModelIsUsableInScanPipeline \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationModelRecognizesIndependentPhotoWithInstanceMasks \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOLiveScanUsesStableRealtimeCandidates \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationModelRecognizesNewNonVideoImages \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationBookshelfBookHasMaskAndLabel \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationOverlaySuppressesFurnitureAndDuplicateBookTags \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationEvaluationDatasetReportsScenarioHitRate \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOSegmentationObjectLevelEvaluationReportsTargetRecallAndLocalization \
  -skip-testing:SmartPawTests/SmartPawTests/testYOLOMasksHaveSaneRasterCoverageForIndependentPhotoQualityGate \
  test CODE_SIGNING_ALLOWED=NO
```

## 提交前仍需取得的证据

真实设备上完成相机首次授权、拒绝后恢复、连续进入退出、前后台切换、拍摄取消/超时，以及实际房间照片的识别结果核对。模拟器测试不能证明真机相机会启动，也不能证明任意环境的识别准确率。宣传和审核说明应描述为“本地识别候选，由用户确认、修改或手动添加”，避免承诺全场景自动识别和精确定位。
