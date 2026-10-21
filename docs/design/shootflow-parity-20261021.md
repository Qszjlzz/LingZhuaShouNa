# 拍摄与整理流程：Figma 差异复核（2026-10-21）

本次为只读源码及已有截图复核，仅新增本文档。没有修改 `ShootFlow.tsx`、操作共享 Figma / 模拟器、重建 dist 或安装 App。实际源文件为 `FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx`，根路由为 `App.tsx`。

结论：当前拍摄后的检查照片与添加照片状态仍存在，但真实方案执行界面不符合已保存的 Figma `2354:32` 外观，尤其分类图卡与底部操作缺失。详细整理组的 21 个 frame 尚无完整近距逐屏证据，不能将本报告称为所有拍摄 / 整理页面已达成一模一样。

## 参考及证据边界

- [拍照+扫描结果预览 `2261:2809`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-2809)：已有 `app-analysis/figma-reference/full-audit-20261021/capture-ar-preview-overview.png`。37% 画布截图足以核对四种屏幕结构和说明，不适合量取精确字体、间距或像素色值。
- [ShootFlow `2354:32`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2354-32)：已有 `full-audit-20261021/shootflow-single.png`，选中尺寸明确为 390 × 844。55% 画布截图能辨认黑色上区、白色引导面板、分类图卡与操作区；精确视觉参数仍需完整原尺寸导出或近距核对。
- [收纳具体流程 `2261:6479`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-6479)：已有 `organizing-flow-overview.png` 和 `organizing-flow-12pct-middle.png`。后者可辨认区域一、区域二以及多步图卡结构，但不支持逐行文案、每个边距或所有 frame ID 的映射。
- `MakePreview` 和 Git HEAD 仅用于动效基线与实现历史对比，不作为最终 Figma 布局权威。保持现有 React + WKWebView 架构是当前任务约束，不因技能中的默认 SwiftUI 实现建议重写架构。

## 四张拍摄 / AR 画板

| Figma 手机 | 当前离散状态 | 源码观察 | 结论 |
| --- | --- | --- | --- |
| 拍照 `2261:1753` | `CaptureStep`，`mode=photo`，`previewMode=false` | 原生相机透底，关闭、连拍 / AR 切换、角标、闪光、计数、快门、完成；权限或相机失败时额外显示重试和相册选择 | 结构存在。尚无本轮相同内容 / 同尺寸截图一对一比对，不能称精确一致；失败提示为业务异常状态 |
| AR `2261:1478` | `CaptureStep`，`mode=video`（UI 文案 AR 扫描） | `arTags` 使用真实扫描结果；AR 下隐藏连拍底部 dock，保留上方关闭和通道切换 | 与设计说明的“AR 只在取景框弹物品名称”方向一致。真实帧率、标签位置及外观未在本轮运行验收 |
| 检查照片 `2261:2105` | `CaptureStep`，`previewMode=true`，`currentIdx < shots.length` | 黑底、张数标题、照片与真实标签、轮播点、重拍这张、删除、提交；保留缩放 / 淡入与轮播过渡 | 页面仍存在。不能因为旧 `ReviewStep` 未被挂载就写成“检查照片页缺失” |
| 添加照片 `2261:2469` | 同一 preview，`currentIdx === shots.length` | 黑底“添加照片”标题、虚线加号卡；重拍 / 删除禁用，提交依赖已有照片 | 离散状态存在；虚线卡尺寸、底部间距尚未逐像素核对 |

`ShootFlow.tsx:296` 的注释“检查照片页已删（设计稿没有这屏）”不准确。实际删除的是独立旧 `ReviewStep` 的主线挂载；`CaptureStep` 自带检查 / 添加轮播，Figma 也明确保留这两张手机。后续修改应先纠正该注释，避免重复接入第二套检查页。

旧 `ReviewStep`、`ConfirmStep`、`PromptStep`、`PlansStep`、`PlanStep` 当前只是函数定义，未出现在 `ShootFlow` 的 JSX 路由中；组件存在不能当作这些页面可达的证据。

## 方案、分区与执行状态

| Figma / 流程阶段 | 当前状态与可达性 | 已确认差异 / 未证明部分 |
| --- | --- | --- |
| 方案生成 / 确认 | `generating → plandeck`；可微调到 `tune`，确认后进 `zones` | 生成动画存在，方案卡以真实拍照作为主图。当前近距证据不足以确认两张方案确认稿、两张草图与现有状态的最终版本关系；不能用原版组件存在推定通过 |
| 选择区域：前后两状态 | `zones`，选中数组控制边框和列表；生成方案后直接 `arGuide` | **确定的数据结构差异**：`buildFlowZones` 固定返回一个“收纳区域”，边框固定覆盖 3% / 3% / 94% / 94%；并非真实区域边界。Figma 详细流程具有区域一 / 区域二；当前实现无法产生同样的多区域选择和执行结构 |
| AR 3D 预览 | `arPreview` 有渲染分支和下一步到 `tools` | 正常主线没有 `setStep("arPreview")` 的前进入口。仅直接开发参数或 `tools` 返回可到达；不能称已接通正常用户流程 |
| 工具页 | `tools` 有渲染分支 | 正常主线直接 `zones → arGuide`，工具页同样不在正常前进链中。是否属最终必经画板需与根代理正在核对的版本清单结合，不能擅自插回已弃用页 |
| 区域一：清理、分类、逐组收纳 | `ARGuideStep` 中 `stepIdx` / `nativePlan.steps` | 真实方案模式会隐藏 Figma 的示意图卡，并把区域数设为 1；原生步骤的标题 / 说明替换固定示例文案是合理真实内容，但不应连同参考图卡和操作区一并删去 |
| 区域一完成 | `flow=celebrate`，继续到 `checklist` | 黑色遮罩、绿色完成标和底部白条存在；当前“整理步骤已完成 / 保存实际完成照”文案与示例稿是否相同须近距核实。未做本轮模拟器截图比对 |
| 区域二及区域二完成 | `advanceZone` 具有多区域分支 | 在 `nativePlan` 下 `totalZones=1`；而 `buildFlowZones` 本身也固定一个区域，因此正常数据无法执行区域二。不能以分支代码存在当作该页可达 |
| 全部完成 / 整理前后对比 | 普通主线 `RewardStep` 包含完成照、对比、成就三个状态 | 保存及归档已由主代理另行验证。本轮仅源码观察；`timeBudget` 是方案预算，不能当实际计时或效果提升。前后同一照片的测试不能证明整理效果 |
| 重新点亮：方式选择、微调、拍摄验证、完成 | `RelightFlow`，`choice/tune/plandeck/zones/guide/proof/complete` | 与空间组 `2283:5615/5933/6161/6311/6462` 可建立候选对应，但本轮未读取这些完整画板的近距图；暂不判定文字、色块和排版一致 |

`organizing-flow-12pct-middle.png` 可看到区域一有五个不同引导画面、区域二有三个引导画面，不能用同一张通用文本引导页面代替全部状态后宣称视觉一致。已存图小，精确状态归属由现场选中 frame 后补齐；本文不猜测 frame ID。

## `2354:32` 物品分类屏的确定差异

该 Figma 画板为“桌面区域 · Step 2/5 / 物品分类”，黑色取景区下接圆角白面板，面板含三张橙色分类图卡（化妆品、工作区、生活日用品），底部有“复核 / 跳过 / 下一步”三个操作。

当前 `ARGuideStep`（约 `5776–6137` 行）在正常生成的 `nativePlan` 存在时：

1. `showOverlay = !DEMO_GUIDE && !nativePlan`，因此真实方案不绘制分类区域或收纳位置示意。
2. 清理、分类、收纳示意块均以 `!nativePlan` 为条件；真实方案完全不渲染三类图卡。
3. `!nativePlan && isGroup` 的后备橙卡只显示通用 Box 图标和件数；即便强行去掉条件，也不等于 Figma 原图卡素材与局部布局。
4. “跳过”只在 `!nativePlan` 渲染；“复核”在该组件中没有实现；真实方案只有绿色“下一步 / 完成收纳”按钮。
5. 原生路径 `totalZones=1`，步骤数等于真实方案步骤数。Figma 示例 Step 2/5 的数字可随真实步骤变化，但每步的语义和面板样式仍应有对应，不能以数据变化为理由移除图卡结构。
6. 当前上区显示用户原照片与顶部返回 / 区域胶囊；存档 Figma `2354:32` 的上区为黑色。这一项需要核实画板是否故意留出原生取景位，不能简单把真实相机或照片删成黑底。

前五项可由源码和已存 Figma 图直接支持；第六项是需要版本 / 画板用途确认的差异，不列为可立即照黑改动。

修复时应保留真实步骤 UUID、`plan.step.complete`、完成照前置条件和失败回滚；不能靠启用 `DEMO_GUIDE` 的固定五步图片来假装真实流程通过。示意图片需要独立素材，不能将 Figma 整屏裁图作为产品 UI。

## 动效保留复核

以当前 Git HEAD 的 `FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx` 为基线，使用 Babel AST 提取全部 motion 开标签和 `initial / animate / exit / transition / whileTap / whileHover / layout / layoutId`，去除节点位置元数据后逐序比较：

- HEAD：54 个 motion 元素；当前：54 个。
- 上述动画属性序列完全相同。
- 核对时当前源码 SHA-256：`5a9cbb840249d39b8bf4809b310b479b00c9a2e9cf6fc1d75cda42ecfd1b017a`。

这证明声明没有被本工作区改动删除，不代表所有条件分支能被真实数据触发、所有 CSS / 手工 DOM 动画均相同，或真机帧率与手势已通过。后续修复分类面板时仍需保留快门闪光、轮播弹入、生成动画、最终返回空间粒子与重新点亮完成动效。

## 原生相机与网页复核页的边界（本轮补充源码结论）

实际 App 中网页 CaptureStep 并不依赖原生 CameraCaptureView 弹窗来补检查页：

- 正常拍摄页走 camera.preview.start / frame / stop 内嵌预览（CameraPreviewOverlay），快门直接发 camera.capture（CurrentFigmaMakeWebView.swift:135、captureInline 在 365 行起），网页立即切到自带的 previewMode 检查 / 添加照片轮播（ShootFlow.tsx:1771 起）。
- presentCameraCapture() 弹出的 CameraCaptureView 只服务于 capture.open 且 source 为 camera 的旧通道（CurrentFigmaMakeWebView.swift:281-282）。它有独立的取景加重拍 / 使用照片确认（CameraCaptureView.swift），但确认后仍回 consume() 走扫描，不与网页内检查页冲突。现行主线不会走到这条弹窗。
- 因此检查照片页的最终视觉以网页 previewMode 实现为准（对应 2261:2105 / 2469），不需要再从原生侧加一套照片确认页；如果后续做原生重写，才需要按这两张画板补齐。

## 下一步验收清单

1. 根代理完成 `2261:6479` 的 21 个 frame 实际画布顺序、尺寸、最终 / 草图归属，再映射到离散 app 状态。
2. 为 `2354:32` 和各引导稿取得能辨认原图卡内容的独立素材及近距截图，确定黑色上区用途。
3. 按真实计划语义恢复分类 / 清理 / 收纳的不同面板与必要操作，保留真实保存、进度及失败处理。
4. 根据确认版本决定 AR 预览、工具和早期方案输入稿是否进入正常路由；不要仅为覆盖旧函数而接入。
5. 每个最终 frame 在同尺寸模拟器截图并实际点击主要操作；不足项继续标为未验收，不能由构建成功或 54 个动效节点替代视觉验收。
