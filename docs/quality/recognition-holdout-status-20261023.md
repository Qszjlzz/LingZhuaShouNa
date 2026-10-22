# 50 张真实照片留出集状态（2026-10-23）

当前可计入新 50 张独立真实照片验收集的数量为 **0 / 50**，仍缺 **50 张合格原始照片**。仓库存在旧开发图片和稀疏标注，可以继续作为历史回归样本；没有找到已经冻结、逐图核验来源许可、完整标注且独立于开发调参的 50 张数据。**90% / 95% 仍是用户目标，没有本轮有效测量。**

本次仅审计本地文件、哈希、现有清单、测试逻辑和质量记录；未运行识别或 xcodebuild，未联网下载图片，未外传个人照片，未修改识别源码。使用 llm-writing 的证据写作规范整理此记录。

## 可核查库存

审计范围为 Resources/EvaluationScanTests 和 Resources/ExternalScanTests。逐文件路径、SHA-256、来源记录、旧评测使用情况和排除原因见 [legacy-inventory.json](recognition-holdout-20261023/legacy-inventory.json)。

| 集合 | 本地数量 | 可确认的独立性 / 来源 | 用途与限制 |
| --- | ---: | --- | --- |
| 两个图片目录合计 | 26 个图像文件、21 个不同文件哈希 | 含 3 张 contact sheet、JPG/WebP 格式变体和精确重复文件；文件数、哈希数都不代表独立真实场景数 | 仅库存，不作为留出集样本数 |
| dataset-sources.json | 10 条记录、6 个唯一文件哈希 | 记录的是 loremflickr 查询 URL，未记录原作者、稳定原图 URL 或逐图许可 | 旧候选来源清单；不能按文件名当作十种场景 |
| evaluation-dataset.json | 10 张 | 3 张 external、3 张 editthispic 示例、1 张博客厨房、3 张 loremflickr 室内图；均已用于开发测试 | 场景类别回归集，不能作为首次盲测 |
| object-evaluation-dataset.json | 6 张、16 个目标 | 2 张桌面 + 厨房 + 电钻 + 书架 + 衣柜；只标了明确目标，非完整标注 | 目标召回 / 框定位历史基线；不能计算完整 precision |
| 已核验逐图许可的新留出图 | 0 张 | 仓库未见相应来源/授权记录 | 仍需收集 |
| 已核验家庭 / 物理空间分组的新留出图 | 0 张、0 个可核验分组 | 旧清单没有 household、space、same-scene group 或原始拍摄记录 | 不能证明 50 张来自独立场景 |

### 已确认的数据问题

- eval-real-01-desk.jpg、eval-real-06-laundry.jpg、eval-real-08-toys.jpg、eval-real-09-office.jpg、eval-real-10-boxes.jpg 五个文件 SHA-256 完全相同，均为 **adc7d6d3cfef1f204fe0400b98bb4699efd13e8c8f067f02c37be3a7ff2cb61b**。查看本地 evaluation-contact-sheet.jpg，内容是同一户外猫照片，和五个室内文件名不符。不能当作五个场景或目标域数据。
- candidate-mama-2.jpg 与 eval-real-02-kitchen-counter.jpg SHA-256 完全相同，均为 **dcb6fe69f8dcdd711706fe5f74545335ed858c3925a6f3013e0da70989bfbdcb**。新增文件名没有带来新样本。
- candidate-mama-1.jpg 是户外儿童骑车；candidate-mama-3.jpg 是整洁厨房。它们不满足本轮书桌/茶几目标域。前者还有儿童入镜，未见使用授权；本轮未复制或上传。
- 三张 editthispic 的 JPG/WebP 是同名场景的格式变体，不算六张独立图。来源页为图片清理工具示例；本地记录没有原始拍摄证据、作者和逐图许可，故按“真实性未核验示例”排除。这里没有据此断言它们一定由 AI 生成。
- external-* 中的 pexels、imweb、note 只是文件名线索。evaluation-dataset.json 的来源写成 bundled external photo，不构成授权或出处证明。博客厨房仅保留 tag 页面 URL；loremflickr 仅保留动态查询 URL，均不足以核验原作者和许可。
- 项目其他位置的参考视频帧、Figma 截图、产品演示图、生成图、模拟器截图、重复源代码提交包，不作为新增真实 holdout。连续拍同一桌面、裁剪、换角度或变亮须保留相同场景分组，不能据此声称新增独立空间。

## 现有评测能证明什么

| 证据 | 历史测量 | 边界 |
| --- | --- | --- |
| 2026-10-21 全量模拟器结果 | 10 图场景类别命中 80%，有可用 mask 的场景 80%，平均 3.7 个候选 | 只要求与预期宽类别有交集；不等于物品级准确率或 80% 轮廓准确 |
| 同次对象级结果 | 6 图、16 目标，11 匹配 / 5 漏匹配，目标召回 68.75%，匹配目标 mean IoU 0.643 | 规则同时要求类别、名称 token 和框 IoU ≥ 0.25；稀疏标注的 7 个未匹配候选不全是 FP |
| 本轮独立 50 图结果 | 未执行 | 没有有效 precision、recall、F1、置信区间或 90% / 95% 达标证据 |

历史证据见 [原生全量测试核对](../design/native-test-results-20261021.md)、[本地识别验证记录](../app-store/recognition-validation.md)。旧 2026-08-04 文档中的 90% / 100% 是当时十图的宽类别场景命中率，不能替代最新结果或 50 张物品级验收。

## 已具备与尚缺的评测工具

- SmartPawTests.swift 的 testYOLOSegmentationEvaluationDatasetReportsScenarioHitRate 可通过 SMARTPAW_EVAL_DATASET 指定场景清单，但只输出类别命中 / mask 场景可用率，不输出完整逐实例 TP / FP / FN。
- testYOLOSegmentationObjectLevelEvaluationReportsTargetRecallAndLocalization 使用固定旧 6 图清单，可按 SMARTPAW_OBJECT_EVAL_SAMPLE 选一图；当前只输出稀疏目标 recall 与定位。匹配是一对一，旧门槛是 IoU 0.25。不能不经定义就把旧门槛当成新验收标准。
- 仓库未找到可直接对完整 50 图、三种路由、完整真值、版本化预测计算 precision / recall / F1 的独立汇总脚本或已冻结的十类目录。待数据和规则冻结后再接入，避免把规则测试通过数解释成精度。

## 本轮已准备的采集和标注材料

文件均位于 [recognition-holdout-20261023](recognition-holdout-20261023/README.md)。它们是空白工作材料，不代表图已存在或评测完成。

- collection-intake.csv：50 个 **planned_not_collected** 槽位，35 desk + 15 coffee_table 为项目建议，非用户指定比例；没有原图路径、来源、授权、哈希或标注值。
- object-annotations.csv：仅字段头，逐可见实例记录类别、同义词、归一化框、遮挡、忽略区域、区域归属、mask 与独立复核。
- predictions.csv：仅字段头，保留离线 / 云端 / 降级路径及解析前、解析后、合并后的候选，记录模型、设备、App build、commit、网页 hash 和设置。
- protocol-draft.json：明确 draft_not_frozen，十类目录、匹配 IoU 和忽略规则尚未冻结，results 为 null。

## 解锁验收的确切条件

1. 收集 **50 张可证明为真实拍摄、允许本项目本地评测的原图**，限书桌/茶几；逐张填来源或自拍记录、作者/所有者和授权证据、SHA-256、拍摄日期、设备、家庭及物理空间分组。不得下载一批网络图后仅靠外观称其为真实留出图。
2. 冻结十类核心物品的确切名称、同义词、重复实例计数、严重遮挡 / 模糊 / 忽略策略和匹配阈值。现有交接确认了“十类”的范围，但本次在仓库未找到已冻结十类表；不能从宽类别枚举自行冒充用户定义。
3. 完整标注所有范围内可见目标，第二人复核并裁决争议。目标数随图像真实内容统计，不能预填或凑数；在预测前锁定真值。
4. 冻结评测规则。工程建议仍为 precision 和 recall 分别报告、两者 ≥ 90% 作为首轮候选门槛、95% 为后续目标；这个映射尚非用户已确认口径。位置/区域和轮廓分别报告，不用框 IoU 替代 mask 指标。
5. 固定 build、模型/提示词、设置与设备，分别运行本地离线、云端启用、降级回本地；输出逐实例匹配、TP / FP / FN、分场景结果和失败图。云端上传前须已有相应照片使用范围授权，当前材料不包含该授权。

**当前数据阻塞：50 张合格原图全部未冻结，完整逐实例标注为 0 张；十类目录和新验收匹配规则未冻结。** 本轮真机连续拍摄若只覆盖同一桌面，可用于稳定性验收，但不能直接关闭 50 张独立真实照片精度验收项。


## 用户新增决定：允许 AI 图补训练

2026-10-23 用户允许用部分 AI 生成图补充训练和调试。已将现有供应商输出登记为 1 张未标注训练候选，未追加付费请求、未训练模型。来源许可、输出物品变化和重新标注要求见 [训练补充记录](training-augmentation-20261023.md)。本文件的真实 50 图留出验收数量仍为 0/50，不能把生成候选加入这个实拍分母。
