# 整理项目清单对齐进展 · 2026-10-21

本次复查 Figma 详细整理组，并开始对齐“整理项目”任务清单。页面标题、分组卡、真实步骤状态和保护活动 UUID 的切换行为已经修改；15 项 guide 逻辑测试和 390 × 844 生产网页模拟 bridge smoke 通过。**这不是逐屏 parity 完成：当前原生 `NativeStep.zone` 表示建议归位位置，不保存桌面/桌下实体分区；所以画面和真实双区域步骤仍不能称为与 Figma 一样。**

## 已确认画板

Figma 文件：[ui界面](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2)。已现场选择并读取尺寸的节点均为 390 × 844：

| 节点 | 设计画面 | 参考 |
| --- | --- | --- |
| `2276:2639` | 区域二，桌下数据线整理，Step 3/3 | [Figma 节点](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2276-2639) |
| `2277:32` | 整理项目清单，区域一/桌面区域，5 个快速任务 | [画布总览](../../app-analysis/figma-reference/detailed-flow-20261021/2277-32-area-one-checklist-overview.jpg) |
| `2276:1531` | 整理项目清单，区域二/桌下区域，3 个快速任务 | [画布总览](../../app-analysis/figma-reference/detailed-flow-20261021/2276-1531-area-two-checklist-overview.jpg)、[近距](../../app-analysis/figma-reference/detailed-flow-20261021/2276-1531-area-two-checklist-detail.jpg) |
| `2276:2950` | 区域一，清理垃圾，Step 1/5 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-2950-area-one-cleaning-overview.jpg) |
| `2276:3245` | 区域一，物品分类，Step 2/5 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-3245-area-one-classification-overview.jpg) |
| `2276:3547` | 区域一，化妆品区，Step 3/5 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-3547-area-one-cosmetics-overview.jpg) |
| `2276:3840` | 区域一，工作区，Step 4/5 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-3840-area-one-work-overview.jpg) |
| `2276:4129` | 区域一，生活用品区，Step 5/5 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-4129-area-one-daily-overview.jpg) |
| `2276:2057` | 区域二，清空地面，Step 1/3 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-2057-area-two-cleaning-overview.jpg) |
| `2276:2352` | 区域二，数据线分类，Step 2/3 | [参考](../../app-analysis/figma-reference/detailed-flow-20261021/2276-2352-area-two-cables-classification-overview.jpg) |

详细整理组已核实 21/21 张 frame 的来源画面及尺寸。最后一张 `2276:2639` 已现场选中，确认为桌下数据线整理 Step 3/3，尺寸为 390 × 844。完整画布顺序和各版本关系仍待审计。

## 本次修改

`FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx` 的 `TaskStep`：

- 页标题改为“整理项目”，采用圆角分区选择条和白色任务卡的布局。
- 任务清单由当前 plan 的真实步骤、UUID 和 status 驱动；每个保存仍调用原有完成回调。
- 浏览其他计划分组时，锁住其待完成项，不会完成别组任务；底部操作明确返回活动分组。原生保存失败仍留在当前任务，可重试。
- 全部真实步骤完成后仍进入完成照流程。

分区选择条当前按原生 `NativeStep.zone` 的值生成。代码审计发现此字段是目标收纳位置（例如书架/充电区），不是照片中的桌面/桌下来源区域。因此此 UI 暂时只确保真实计划数据和执行逻辑没有被虚构；它还没有复刻 Figma 的“区域一/区域二”物理分区语义，真实生产计划也可能出现不同数量的归位位置。

完整复刻需要先让用户或可信分割结果给每件识别物品建立唯一的实体区域归属，再通过 bridge 和原生 `StoragePlan` / `StorageStep` 持久化区域 ID、区域内 item IDs 与顺序；之后清单筛选和 5 步/3 步进度才可由真实计划生成。不能按类别、建议归位位置、演示文本或 y 坐标猜实体区域。

## 验证

- `pnpm test:guide`：15/15 通过。
- `pnpm build`：通过；Vite 提示主包超过 500 kB。
- `tests/guide-ui-smoke.mjs`：390 × 844 生产 dist + simulated native bridge 通过，无页面错误。新增断言非活动组待办按钮禁用、点击不发出完成请求；回到活动组后只完成活动 step UUID 并进入下一活动组。
- 页面证据：[生产网页清单截图](../handoff/evidence/task-checklist-parity-20261021/00-task-checklist.png)、[完整 smoke 结果](../handoff/evidence/task-checklist-parity-20261021/result.json)。截图显示的是测试 plan 的三个真实归位位置，并非 Figma 的实体区域一/二区；它只能证明当前 UI 与行为。
- 本轮已把最新内嵌网页包构建进 Debug App，并安装、启动于 iPhone 16 Pro / iOS 18.5 模拟器；[原生启动截图](../handoff/evidence/task-checklist-parity-20261021/native-launch-space.png)只证明新包打开到空间地图。尚未在原生模拟器进入 `TaskStep`，也未做同状态截图差异、Figma 像素验收或多物理区域执行测试。

接续入口是 [HANDOFF.md](../../HANDOFF.md)。设计实体 physical-zone 数据合同并贯通识别物品、原生计划和持久化；不能把本报告的网页 smoke 结果当成全流程验收。
