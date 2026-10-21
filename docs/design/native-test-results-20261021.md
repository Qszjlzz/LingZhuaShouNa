# 原生全量测试结果核对（2026-10-21）

## 结论与证据边界

本次全量结果为 **76 个测试用例，70 个通过，6 个失败，0 个跳过**。日志中的 `15 failures (0 unexpected)` 是 **15 条断言失败**，不是 15 个失败用例。`xcresulttool get test-results summary` 的结构化结果明确给出 `failedTests: 6`、`passedTests: 70`、`totalTestCount: 76`，与日志中去重的测试用例结果一致。

不能将这个结果表述为“全部功能通过”或“可以提交 App Store 审核”。六个失败用例都调用原生照片识别服务，未执行 Sarah 个人页、项目页、徽章组件或日历导航；因此这些失败不是上述 React UI 组件的直接测试失败。但本地识别服务在当前工作区也有改动，且本次没有运行改动前的同环境对照，不能仅凭分类就断言“全是旧问题”或“与本轮所有改动无关”。

此次测试使用全量测试启动时构建的二进制。启动后的最终完成照桥接修改和末次文案修改，不由这份全量结果覆盖；它们的后续构建、定向测试和手动流程验证应另计。

## 运行信息

- 项目 / Scheme：`SmartPaw.xcodeproj` / `SmartPaw`，Debug。
- 设备：iPhone 16，iOS Simulator 18.5，arm64；设备 ID `FA63A134-783E-4983-A62C-08CA35AF70F8`。
- SDK：iPhoneSimulator18.5；宿主系统 macOS 15.5。
- 测试日志：`/tmp/smartpaw-flow-20261021-test.log`。
- 结果包：`/tmp/smartpaw-flow-20261021-results.xcresult`。
- Derived Data：`/tmp/smartpaw-native-bridge-20261021`。
- 测试套件运行时间：约 1339 秒。构建和启动时间另计。

原始命令：

```sh
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw -configuration Debug \
  -destination 'platform=iOS Simulator,id=FA63A134-783E-4983-A62C-08CA35AF70F8' \
  -derivedDataPath /tmp/smartpaw-native-bridge-20261021 \
  -resultBundlePath /tmp/smartpaw-flow-20261021-results.xcresult test
```

本次结果分析只读取已有日志、结果包与源码，没有重新运行全量测试、操作模拟器或修改业务代码。

## 六个失败用例

以下位置均为本次日志记录的 `SmartPawTests/SmartPawTests.swift` 行号。

| 用例 | 断言数 | 直接观察到的失败原因 | 用户影响 |
| --- | ---: | --- | --- |
| `testBundledCoreMLSegmentationModelIsUsableInScanPipeline` | 2 | 第 210、211 行：`CoreMLSegmentationScanService` 在杂乱书桌照片上返回空数组，无法返回可渲染 mask。模型入包检查本身未失败。 | YOLO 需要降级到 DeepLab / Vision 时，该样本不能得到可确认的物品和高亮。不能证明 DeepLab 在真机上一定失败，但当前模拟器链路未达到测试要求。 |
| `testVisionScanServiceBuildsBaselineForIndependentPhotos` | 6 | 第 192、193 行循环三张照片：`external-messy-desk-note.png`、`external-cluttered-study-pexels.jpg`、`external-trash-room-imweb.jpg` 均无候选，也无 AR 区域；每张两条失败。 | 系统 Vision 降级识别对这三类真实场景没有自动结果，需要其他识别路径或用户手动录入。 |
| `testVisionScanServiceScansBundledIndependentPhotoWithARHints` | 2 | 第 180、181 行：同一杂乱书桌照片无候选、无 AR 区域。与上一用例的书桌样本重复覆盖，不能当作新场景问题累加。 | 与上述书桌 Vision 降级失败相同。 |
| `testYOLOSegmentationEvaluationDatasetReportsScenarioHitRate` | 2 | 第 361 行：10 图中 `external-trash-room-imweb` 与 `eval-real-07-garage` 各返回 0 个物品。总体 80% 类别命中率、80% 可用 mask 比例虽达到该用例的总体下限，但“每张至少有一个候选”断言失败。 | 杂物堆和车库 / 电钻照片可能出现零识别结果，不能直接自动生成覆盖照片物品的方案。 |
| `testYOLOSegmentationModelRecognizesNewNonVideoImages` | 2 | 第 266 行：杂乱书桌只得 4 个可渲染 mask，低于测试要求的 8 个；杂物堆为 0，低于要求的 1 个。 | 桌面流程能拿到电脑、杯子、书本、手机四个候选，但识别数量不满足当前质量门槛；杂物堆仍无自动结果。最低 8 个的门槛需结合人工标注审核，不能为通过测试直接降低。 |
| `testYOLOSegmentationObjectLevelEvaluationReportsTargetRecallAndLocalization` | 1 | 第 413 行：6 图、16 个标注目标仅 11 个匹配，5 个漏匹配，未达到要求的 16/16。平均 IoU 为 0.643，超过该用例 0.620 的定位均值下限，失败点是目标匹配数。 | 候选数量 / 场景命中不代表目标完整识别。部分物品缺失，或名称、类别、位置不足以匹配人工标注，生成计划前仍需用户确认。 |
| 合计 | **15** | **6 个去重失败用例** | 主要剩余风险为自动识别覆盖率和定位。 |

## 识别效果的实际数值

10 图场景测试报告为：类别命中率 80%，有可用 raster mask 的图片比例 80%，每图平均 3.7 个候选 / 3.7 个 mask，候选平均置信度 55%。类别命中只要求命中该图预期类别中的任意一个，不代表图中 80% 物品被正确识别，也不代表 80% 轮廓准确。

6 图对象级结果如下。匹配条件同时包含名称 token、类别和边框 IoU（最低 0.25）。因此“漏匹配”可能来自漏检、分类 / 命名不符或位置不符，日志本身不支持把五个目标一律归因于模型完全没看到。

| 样本 | 匹配目标 / 标注目标 | 未匹配候选 | 已匹配目标平均 IoU |
| --- | ---: | ---: | ---: |
| `external-cluttered-study-pexels` | 2 / 4 | 1 | 0.779 |
| `external-messy-desk-note` | 3 / 4 | 1 | 0.643 |
| `eval-real-02-kitchen-counter` | 4 / 4 | 3 | 0.552 |
| `eval-real-07-garage-drill` | 0 / 1 | 0 | 0.000（无匹配） |
| `eval-real-04-bookshelf` | 2 / 2 | 1 | 0.691 |
| `eval-real-05-closet` | 0 / 1 | 1 | 0.000（无匹配） |
| 总计 | **11 / 16（68.75%，日志四舍五入 69%）** | **7** | **0.643** |

`unmatched_candidates` 不是完整标注集上的假阳性计数：标注清单只标了明确且与收纳相关的目标，因此不能据此计算精确率或宣称其余七个候选都是错误识别。

## 原因判断与本轮 UI 改动的关系

三类 Vision / CoreML 失败直接发生在原生服务调用，未经过 Web 页面。当前 `VisionScanService` 会在没有可核对的分类 / OCR 结果时返回空数组，不再用全图场景名称充当物品；`CoreMLSegmentationScanService` 只给 Vision 已得到的候选补充区域，不会单凭 DeepLab 区域创造物品，所以 Vision 为空时其结果也会为空。这可以解释两个服务的连带空结果，但日志没有输出底层每个 Vision 请求结果，无法进一步确定系统分类模型、类别映射和运行时分别承担多少影响。

当前工作区还包含模拟器 CPU 计算设备配置和移除场景名称假物品的原生识别改动；不能将 Vision 测试失败直接归咎于 iOS 模拟器。本次没有未修改版本的同样本对照，也没有真机同样本结果。

YOLO 主路径使用多模型、OCR、mask 精修及回退服务，当前主路径在桌面样本可以得到真实 mask，但在杂物堆和电钻场景没有候选。此类识别质量需要独立修复和人工标注核验，Sarah 个人页、徽章展示、项目标题与移除日历不会直接解决。

## 已通过内容与未证明内容

本次通过了计划暂停 / 继续与失败回滚、归档方案复用与独立步骤 ID、完成要求整理后照片、完成写入失败不产生假成就、手动物品与无定位信息的文字计划、存储恢复与清空、迟到识别结果隔离、云端授权设置、实际 mask 的基本覆盖率、两张静态照片走实时识别接口等单元测试。

这些通过结果证明的是对应原生方法在测试数据和 mock 条件下的行为。它们不等同于全部 iOS 手势、相机实时帧率、真机 AR、Figma 全画板视觉一致性、云服务真实网络可用性、所有徽章规则或 App Store 提审资格。尤其“实时识别”通过用例是在两张静态照片上调用 `scanLiveImage`，没有测量持续相机流的帧率。

主代理另行记录当前最终包的模拟器界面和手动全流程证据；这里不将手动证据合并为全量自动化测试通过。
