# 灵爪收纳：跨电脑 / 新对话交接

更新日期：2026-10-21（Asia/Shanghai）。本文供只能访问 GitHub、看不到原聊天记录的新对话接手。

**当前任务：逐张核实 Figma 的正式手机画板，让实际 iOS App 的对应界面与设计一致，并保留原有动效和真实业务。任务尚未完成。** 当前分支是工作进度快照，存在已知差异和未通过的识别测试，不能称为最终定稿或 App Store 可提交版。

接手时先切到下方交接分支并检查工作区，再读用户决定、当前缺口和最新[整理项目清单对齐进展](docs/design/task-checklist-parity-20261021.md)。详细整理组的 **21 / 21 个 frame 来源画面及 390 × 844 尺寸均已现场核实**；`2276:2639` 是桌下数据线整理 Step 3/3。画布完整顺序/版本关系及 App 逐屏实现验收仍未完成。第 6 节列出继续工作的顺序。

## 1. 从哪份代码接手

- 仓库：[Qszjlzz/LingZhuaShouNa](https://github.com/Qszjlzz/LingZhuaShouNa)。
- 本次交接分支：`codex/figma-ui-handoff-20261021`。请从此分支开始；只克隆默认 `main` 会拿到较旧代码。
- 交接入口：[本文件](HANDOFF.md)；结构化状态：[current-state-20261021.json](docs/handoff/current-state-20261021.json)。
- 提交身份以 GitHub 分支和 `git rev-parse HEAD` 为准。本文随快照提交，不把本地尚未提交的文件误当作远端已有内容。

```sh
git clone --branch codex/figma-ui-handoff-20261021 --single-branch https://github.com/Qszjlzz/LingZhuaShouNa.git
cd LingZhuaShouNa
git status --short --branch
git log -1 --oneline
```

原始交接快照的基点是本地提交 `09c5191`；之后分支继续累积修复。远端 `main` 为 `18fa9eb561f11b304bdd66b4ffd7c6ec8e7d4601`；远端 `真实AI生图步骤` 为 `3196dd6d9e5b48a4a6ec9dc205f736e7efeb0fcc`，不是本轮更新。接手时以本分支最新 `git rev-parse HEAD` 和工作区状态为准。不要将它称为用户过去说的“GitHub 最终版”。

## 2. 用户真正要什么，哪些已决定

用户发现 App UI 与最终 Figma 相差较大，要求聚焦画布中的**手机框 UI**，逐张找到正式版本并复刻。海报、logo、比赛展板不作为独立 App 页面实现。同一功能有多套无法判断的稿件时，拿候选截图和定位链接向用户确认；不要只用抽象名称提问，也不要自行选方便实现的版本。

以下决定已经确认，不要重新问：

| 项目 | 用户决定 |
| --- | --- |
| 个人主页 | 采用 **Sarah Chen** 那版，使用原浣熊头像，加上徽章；旧“收纳等级 Lv.3”不采用 |
| 第三个非相机底栏入口 | 名称为 **项目**；中间凸起相机不计入栏目顺序 |
| 项目页内容 | 使用个人分组的 **我的计划** 卡片设计；页面标题为“项目”，个人页入口仍可叫“我的计划”，二者通向同一处 |
| 日历 | 独立日历页面及导航入口不要；也不要因别处画板有月历又重新接回。排期数据仍可出现在项目列表 |
| 社区 | 原底栏社区由项目替换，社区案例页暂不作为该入口主界面 |
| 动效 | 保留原有动效，不能改完 UI 把原动画都删掉 |
| 其他页面 | 继续按 Figma 正式手机画板对齐，不自行改版 |
| 架构 | 沿用现有 React + 原生 WKWebView，不为了技能默认建议另写一套 SwiftUI 页面 |

早期用户曾要求达到提交 App Store 审核的标准，随后明确要查看原 GitHub 版本并还原 Figma。目前优先完成界面与真实流程；上架准备资料保留为背景，不要让“上架改版”覆盖此次设计目标。用户尚未准备付费开发者资格、模型商业授权、正式支持邮箱和公开隐私政策网址。

## 3. 设计源、证据与阅读顺序

Figma：[ui界面 / Page 1](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2)。截至本次核实，可通过只读浏览器查看；新电脑需要重新获取工具和访问状态。未配置可直接使用的 Figma MCP，不能假定原工具会随仓库迁移。

先读下列文件，再动界面：

1. [全部画板盘点及节点 ID](docs/design/figma-full-inventory-20261021.md)：目前的覆盖与缺口，**并非全文件已核完**。
2. [个人、徽章、项目专项](docs/design/personal-project-figma-verification-20261020.md)：用户决定、素材来源、动效、真实数据边界。
3. [拍摄与整理流程差异](docs/design/shootflow-parity-20261021.md)：接下来最明确的界面和多区域问题。
4. [整理引导进度修复与增量验收](docs/design/guide-progress-repair-20261021.md)：本轮清理/分类/复核恢复、真实 UUID 推进、测试证据与剩余边界。
5. [完成流程对齐与最新验证](docs/design/completion-flow-parity-20261021.md)：完成照取景、对比到地图成就弹窗、三张新增画板及最新资源。
6. [整理项目清单对齐进展](docs/design/task-checklist-parity-20261021.md)：9 张整理清单/步骤画板核实、TaskStep 改动和 physical-zone 数据缺口。
7. [重拍路由](docs/design/reshoot-route-verification-20261021.md) 与 [空间数据](docs/design/spatial-flow-data-verification-20261021.md)：数据接线与验收范围。
8. [76 项原生测试结果](docs/design/native-test-results-20261021.md)：旧全量识别测试失败原因和量化结果；本轮未重跑全量。
9. [画板到 App 状态的映射入口](docs/figma-screen-map.md)：继续按实际画布顺序补齐。

| 证据目录 | 内容 | 使用边界 |
| --- | --- | --- |
| [full-audit-20261021](app-analysis/figma-reference/full-audit-20261021/) | 空间以外已保存的分类、拍照/AR、详细整理、项目长页和展板总览 | 多为低缩放画布截图；一些 `.png` 实际为 JPEG。不能量取精确字体/间距 |
| [verified-20261020](app-analysis/figma-reference/verified-20261020/) | 个人、徽章、我的计划近距参考、头像来源、早期模拟器截图 | `fixture` 是临时测试数据；早期 `profile.png` 不是最终头像证据 |
| [verified-20261021/simulator](app-analysis/figma-reference/verified-20261021/simulator/) | 最新普通主流程、真实空态、完成项目及个人 4/1/1 统计 | 用于证明对应状态，不能推及所有页面/真机/动效 |
| [handoff evidence](docs/handoff/evidence/) | 初次交接的资源指纹、网页构建与静态门禁历史结果 | 初次快照，不是当前所有测试或全 App 通过报告 |
| [guide-20261021](docs/handoff/evidence/guide-20261021/) | 本轮浏览器与真实模拟器截图、原生测试摘要、最新资源指纹 | 具体通过范围及缺测项见增量报告 |

## 4. 实际运行哪套代码

唯一当前根入口：

```text
App/SmartPawApp.swift
  → App/RootView.swift
  → App/CurrentFigmaMakeWebView.swift
  → Resources/FigmaMakeLatestWeb/（打包进 App 的网页）
  ← FigmaMakeLatest-v3/src/app/App.tsx（维护源码）
```

| 路径 | 责任 |
| --- | --- |
| `FigmaMakeLatest-v3/src/app/components/` | 正在运行的界面源码：SpatialScreen、ClassificationScreen、BooksCategoryScreen、MineScreen、BadgesScreen、MyPlansScreen、ShootFlow 等 |
| `FigmaMakeLatest-v3/src/app/nativeBridge.ts` | 网页与 Swift 之间的请求及状态类型 |
| `App/CurrentFigmaMakeWebView.swift` | bridge 分发、相机与完成照等原生通道 |
| `App/AppViewModel.swift` / `Models/SmartPawModels.swift` | 真实空间、物品、计划、暂停、步骤、完成归档与回滚 |
| `Services/SmartPawServices.swift` | 本地识别、计划生成和存储等服务 |
| `Resources/Models/` | 已在仓库中的 Core ML 权重；不要把本机编译产物 `*.mlmodelc` 加入仓库 |
| `MakePreview/` | 原版实现/动效历史参考，不是最终 Figma 权威，也不是 App 生效入口 |
| `WebDemo/`、旧 SwiftUI 页面、未挂载组件 | 历史/辅助代码；存在文件不代表正常路由可达 |

修改 JSX 后只做 `npm run build` 不会自动更新手机。必须同步内嵌网页并重新构建 iOS。`vite.config.ts` 保留 IIFE 和图片内联配置；原生会将 JS 读成普通脚本，随意恢复默认 ESM 可能造成白屏。不要用整屏设计截图当 UI。

## 5. 当前已经做到的内容

这些是已有实现或有限验收，**不等于全 App 完成**：

- Sarah 个人页、原 Figma 头像、12 枚徽章目录、徽章墙及单枚详情已连接。手机统计/收藏读取真实状态；没有 bridge 的浏览器预览仍显示设计示例数据。
- 项目 Tab 使用 MyPlansScreen，“我的计划”也指向同一 Tab；四个筛选和暂停/继续已连接，日历/旧社区不在当前启动依赖闭包。旧组件文件仍在，不需要为了证明移除页面就删历史源码。
- 空间地图和进行中详情使用原生 UUID、物品、方案及动作。保存失败不先显示成功；暂停、步骤、完成照、归档有真实持久化与回滚。
- compare / same / new 已区别处理：重新点亮、沿用历史方案、新方案；`plan.reuse` 创建独立方案/步骤 ID、重置进度、保留已完成历史。
- 重新点亮链路已接入识别等待、方案生成、真实执行及完成照暂存；点击确认才归档，重拍/退出清理暂存。完成照确认修复还覆盖普通主流程、项目页和进行中详情的生产入口；当前已有模拟器相册选图验收，但真机相机与完整 Figma 视觉验收未完成。
- 最新无进行中计划的空间页：完成过整理显示“开始下一次整理”，首次仍显示“开始第一次整理”。最终模拟器重启画面已看见新文案。
- 本轮真实原生方案补回清理 → 分类 → 复核 → 真实归位步骤入口。清理和分类是前置指引，不计入原生完成步数；跳过仅作用于这两个前置阶段。归位步骤按真实 UUID 调用原生保存，确认最新状态为 `done` 后才推进；保存失败留在当前步骤。
- 普通整理和重新点亮生成后都会把最新原生物品送入分类 UI；卡片按步骤 `itemIDs` 配对，key 使用步骤 UUID，不按数组位置猜测。多于三组可横向浏览并在恢复时滚到当前组。
- 本轮前置阶段以 plan UUID 隔离保存到 WKWebView `localStorage`。浏览器 reload 和原生 active/done 优先逻辑已测；WKWebView 被系统杀掉后的本机 localStorage 恢复尚未单独实测。
- 当前内嵌网页资源为 `Resources/FigmaMakeLatestWeb/assets/index-D2k5Ko03.js`，SHA-256 为 `66a538a78b1a6fb8eb6e6f3afb70e3476eedc7eb3ec21e12f5579d505856084d`；`index.html` SHA-256 为 `520e6bc03ad1d9c10f02224e0d6db47b174548b3fe92d6b7323766513ad8a8e2`。fresh dist 与内嵌资源一致；包含该资源的 Debug App 已构建、安装并启动到 iPhone 16 Pro / iOS 18.5 模拟器空间地图，截图在[本轮证据](docs/handoff/evidence/task-checklist-parity-20261021/native-launch-space.png)。这没有证明 TaskStep 的原生路由或全屏 parity。
- 之前整理引导修复比较到 54 个 JSX motion 元素及相同动画属性序列；这是历史快照。本次将完成碎片庆祝和按钮弹性参数迁至归档确认按钮后，未重跑全文件 AST 比较，不能继续称当前全文件动效声明完全不变。

### 本轮整理引导验收

[增量报告](docs/design/guide-progress-repair-20261021.md)记录整理引导修复：15 项逻辑测试、生产 dist + 模拟 native bridge 的浏览器交互测试（390 × 844，无页面错误）以及 4 项原生定向测试通过。之后完成照暂存修复另有生产 dist smoke 和真实原生模拟器验收，范围、证据与限制见下节及[完成照验收证据](docs/handoff/evidence/completion-photo-20261021/)。

本轮最终 App 已在 iPhone 16 Pro / iOS 18.5 模拟器安装并启动；真实原生 bridge 的普通整理主线走到待完成照状态并验证重启未归档。完成照选择、暂存预览、确认归档则在后续定向模拟器操作中验证，见下节。测试图片来自模拟器相册，不是真机相机验收。重新点亮、新流程实际 UI 保存失败及 WKWebView localStorage 跨进程重启恢复仍未由本轮模拟器流程验证。

### 本轮真实原生 bridge 整理主线

引导修复快照 `index-Cym_NAvg.js` 已随 App 构建、安装并启动。使用模拟器相册中的仓库书桌测试图，实际通过：正常入口 → 选图 → 检查照片 → 提交并生成 → 确认方案 → 单区域 → 清理 → 分类（书籍 1 件、电子产品 2 件）→ 复核（两项均未完成）→ 返回 → 跳过前置分类 → 完成两个真实 UUID 步骤。原生进度先后显示 `done/active`、`done/done`；庆祝页准确显示 2 个完成步骤；清单两项均打勾。由于没有拍完成照，`completedPlans` 始终为 0。强制结束 App 后重新启动，空间页保留 100% 进度并显示“待保存完成照”，说明未误归档；另已只读核对 Swift 对应持久化数据。

证据在 [本轮模拟器截图](docs/handoff/evidence/guide-20261021/)：`08-native-cleaning.png`、`09-native-classify.png`、`10-native-review.png`、`11-native-second-step.png`、`12-native-completed.png`、`13-native-checklist.png`、`14-native-restarted.png`。这些截图证明模拟器和测试照片下的真实原生进度/重启状态；不证明真机相机、完成照存储/归档（该项另见下方第 5 节）、重拍、重新点亮或异常保存回滚。

### 真正在模拟器走过的普通主流程

相机不可用 → 从相册选择测试书桌图 → 得到电脑/杯子/书本/手机 4 个候选 → 提交 → 选择方案 → 确认/选区域 → 完成实际持久化的 3 步 → 取消一次完成照（仍保留进行中计划、不归档）→ 再选完成照 → 保存归档 → 前后对比/成就 → 加入我的家 → 项目完成筛选出现记录 → 重启后保留空间，Sarah 统计显示 **4 件物品 / 1 个已整理空间 / 1 枚徽章**。

前后用了同一张测试照片，**只证明保存、路由与归档，不证明房间变整洁或效果算法有效**。`hasVerifiedComparison` 当前只能说明前后照被保存，不能把字段名当作质量判定。

参考：[真实识别](app-analysis/figma-reference/verified-20261021/simulator/final-photo-recognition.png)、[项目完成记录](app-analysis/figma-reference/verified-20261021/simulator/final-project-completed.png)、[Sarah 实际统计](app-analysis/figma-reference/verified-20261021/simulator/final-profile-earned.png)。最后一次已获得徽章直接点击操作遭遇工具故障，`final-badge-after-click.png` 不应自动算作该操作通过。

### 完成照暂存与归档：已完成限定验收

本轮把完成照从“选中即归档”改为“选中后先预览、确认后再归档”，覆盖正常 ShootFlow、项目页和进行中详情三个生产入口。重拍/重新选择和稍后退出会清理暂存；归档失败时预览保留，可再次确认。相机启动等待期间离开页面也会停止后续重试。

- `pnpm test:guide`：15 / 15 通过。
- 生产 dist + 模拟 native bridge 的 390 × 844 Playwright smoke 通过，无页面错误；覆盖相册取消、相机/相册暂存、重拍取消、稍后退出取消、防重复操作、归档失败重试及确认后只归档一次。结果：[web-smoke-result.json](docs/handoff/evidence/completion-photo-20261021/web-smoke-result.json)。此项不证明原生持久化。
- iOS Debug 构建成功并安装到 iPhone 16 Pro / iOS 18.5 模拟器。真实系统相册选图后，确认预览时原生状态仍有 `activePlan` 且 `completedPlans=0`；点击确认后 `activePlan` 清除、`completedPlans=1`。证据：[预览态](docs/handoff/evidence/completion-photo-20261021/native-progress-preview.png)、[归档态](docs/handoff/evidence/completion-photo-20261021/native-archived.png)。
- 这次仅证明模拟器相册路线的暂存与归档门槛。没有验证真机相机、原生存储失败重试、重新点亮完成照全路线或完整 Figma 像素一致性。模拟器中的归档是测试数据，不是用户手机内容。

### 最新完成流程对齐：网页路线通过，新包已启动

完成照页按 `2261:3290` 上移提示条，并保留底部单独快门。相册入口放在提示条相机图标内，退出使用左边缘向右滑；拍照忙碌时有同步锁防止退出。这个操作约定仍需在 iPhone 上验证可发现性和真实触摸侧滑。

对比页 `2261:3091` 的“查看成就”在原生确认归档成功后播放原碎片动画，再直接返回空间地图显示 `SpatialScreen` 的“加入我的家”弹窗（`2261:5907`）；额外的独立全屏完成卡已移除。原按钮弹性参数和碎片参数保留。对比页仍有“稍后完成”“重新拍摄”操作，逐屏视觉对齐尚未验收。

本次重新通过 15 项逻辑测试、390 × 844 生产 dist 模拟 bridge smoke（无页面错误），并用 `SmartPaw` scheme 构建 Debug 包，在 iPhone 16 Pro / iOS 18.5 安装和启动到空间地图。最新完成照到地图弹窗的路线只由本次网页 smoke 验证，未在原生模拟器重走；较早原生相册暂存/归档结果仍按上节范围解读。

新增画板已现场确认：`2261:3091` 为前后对比；`2261:3457` 为区域一完成并加载下一区域；图层名仍叫“区域1完成”的 `2276:1795` 实际为区域二完成。三张均为 390 × 844。当前单物理区域方案尚不覆盖两区域行为，不能把核实设计身份写成实现完成。

完整证据、剩余差异与复跑命令见[完成流程报告](docs/design/completion-flow-parity-20261021.md)和[本批证据](docs/handoff/evidence/completion-flow-20261021/)。

### 整理清单与逐步引导：设计身份已核实，模型未对齐

本次从 Figma 现场核实区域一桌面 5 项、区域二桌下 3 项清单，以及区域一 5 个步骤、区域二 3 个步骤。随后直接选中最后一张 `2276:2639`，确认为桌下数据线整理 Step 3/3，尺寸为 390 × 844。详细整理组现在 21/21 张画板身份/尺寸已核实；完整画布顺序和版本关系仍需整理。

`TaskStep` 已开始采用“整理项目”清单卡布局，按当前真实 plan steps 显示和切换，查看非活动组时禁止完成别组步骤；归位仍调用原生 UUID 并保留失败重试。15 项逻辑测试与 390 × 844 生产网页模拟 bridge smoke 通过。smoke 直接断言非活动组待办按钮禁用、点击不发出完成请求，截图及完整结果见 [TaskStep evidence](docs/handoff/evidence/task-checklist-parity-20261021/)。

**该页面仍未与 Figma 一模一样。** 现有 `NativeStep.zone` 表示目标收纳位置（如书架、充电区），并不表示照片中的桌面/桌下物理分区；不能拿它冒充“区域一/区域二”。需要先为识别物品建立可靠且唯一的实体区归属，贯通 bridge 与原生 plan 的持久化，再让清单和执行步骤按该物理区筛选。本轮 Debug App 已在模拟器启动到空间地图，但没有进入 TaskStep 的原生截图或逐屏像素验收。

### 动效已知证据

徽章与原 MakePreview 的 AST 比对：16 个 motion 元素、43 组动效参数保留；之前整理引导快照中，ShootFlow 的 54 个 motion 元素、SpatialScreen 的 23 个 motion 元素与当时 Git HEAD 动效属性一致（计入 AnimatePresence 时空间共 30 个节点）。本次迁移动画后没有重做全文件比较。浏览器中徽章钻石的 transform 两次取样有变化。这些证明指定声明和一处运行动画，不能替代全部动效、真实路由触发或真机帧率验收。

## 6. 接下来按什么顺序做

### A. 先补全正式画板清单和版本关系

- [x] 现场选中核实最后一张 [`2276:2639`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2276-2639)：桌下数据线整理 Step 3/3，390 × 844。21/21 张设计源身份及尺寸现已核实；画布完整顺序和版本关系仍要整理。
- [ ] 重建详细整理组 21 张 frame 的完整画布顺序和版本关系；源身份/尺寸核实不等于已确认实施顺序。
- [ ] 补齐剩余根节点、Frame 7、Page 2、独立 RelightCompleteStep / SpatialScreen、旧 Container 的版本关系。不能只按节点 ID 新旧判断最终版。
- [ ] 本次现场确认 Frame 9、10、11 是比赛展板，不作为独立手机页面；其内容可帮助定位，但不能把展板内重复手机再累加。
- [ ] 为每个正式画板记录：节点链接、画布位置/尺寸、页面/弹层/状态、主要控件、对应 App 离散状态、素材来源、待确认点、Figma 截图、模拟器截图和差异。
- [ ] 若有多套都像正式稿，截出候选图向用户确认。先继续不依赖该选择的部分，不要自行缩小全量范围。
- [ ] 建立照片中桌面/桌下区域的真实 item assignment 和 `physicalZoneID` 持久化，再复刻区域一 5 项、区域二 3 项清单与相应执行/完成步骤；不能用 `suggestedZone`、类别或演示数组伪装来源区域。

### B. 修复已经找到的差异，再逐屏验证

#### 方案页 / 微调页的最新源码审计

2026-10-21 补查 `FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx` 后确认：

- `PlanDeckStep` 固定读取 `plans[0]`，注释明确写着“现在只定一种方案”。即使上游传入多项，也不会出现多方案横向选择。见 [ShootFlow.tsx:801](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L801) 和 [ShootFlow.tsx:814](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L814)。
- 方案卡上的“确认方案，开始整理”调用 `setStep("zones")`；它本身还没有生成原生执行计划。`plan.generate` 在区域页点击继续时才执行。见 [ShootFlow.tsx:358](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L358) 和 [ShootFlow.tsx:382](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L382)。因此对 Figma 时要分别核对方案确认与区域选择两个状态，不能把这两个按钮行为合并描述。
- 微调消息会调用 `chat.send` 并显示回复，但确认时构造的 `refined` 只改 `name` 和 `vibe`，不会改 `changes`、时长、方案图或原生步骤。当前聊天回复不能证明执行计划已按用户要求调整。见 [ShootFlow.tsx:1111](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L1111) 和 [ShootFlow.tsx:1140](FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx#L1140)。
- **本轮已更正的 Figma 画板身份**：[`2261:5717`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-5717) 是快速整理方案首屏；[`2261:3989`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-3989) 是尚未选区的分区选择；[`2261:3719`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-3719) 是桌面区域已选中的分区选择；[`2261:6249`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-6249) 是方案微调聊天；[`2285:11376`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2285-11376) 和 [`2285:11580`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2285-11580) 是两种正式加载状态；[`2261:3290`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-3290) 是完成照拍摄画面；[`2261:5907`](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-5907) 是空间地图上的成就弹窗。以上均为 390 × 844，已选中身份的截图位于 [`detailed-flow-20261021`](app-analysis/figma-reference/detailed-flow-20261021/)；详见[完整盘点新增核验表](docs/design/figma-full-inventory-20261021.md#近距选中后的用途修正)和[画板映射](docs/figma-screen-map.md)。图层名与旧记录不可靠。其余未核对的 frame 和版本关系仍需继续检查。
- 因此“显示 plans[0]”目前不能仅凭单张快速方案首屏称为已确认差异，也不能先做多方案轮播。区域选择两种状态则有明确设计证据：当前 `buildFlowZones` 固定一个全图区域、原生只执行一个物理区域，无法覆盖选区 UI 和区域二真实执行；修复前要先建立可靠的照片分区数据。
- Figma 完成流程中，`2261:3290` 是拍摄完成照；右邻 `2261:3091` 已独立选中核实为整理前后对比页，CTA“查看成就”；再右侧 `2261:5907` 是“加入我的家”弹窗。最新实现已直接进入地图弹窗，验证范围见上方最新增量。`2261:3457`、`2276:1795` 分别是区域一、区域二完成状态，见[新增画板记录](docs/design/completion-flow-parity-20261021.md#设计依据与画板关系)。真机相机、原生保存失败重试与逐屏视觉验收仍待完成。
- 方案微调聊天 `2261:6249` 已核实，与 `5717` 首屏相邻；源码仍只更新方案名称和氛围文字，不改实际执行步骤。接下来应对照画板控件与可执行的真实步骤变更来处理。

| 优先项 | 目前证据 / 下一步 |
| --- | --- |
| 整理执行分类页 | 清理、分类、复核、仅前置跳过与真实 UUID 归位推进已在模拟器主线验证；见上方 [模拟器截图](docs/handoff/evidence/guide-20261021/) 和[增量验收](docs/design/guide-progress-repair-20261021.md)。仍缺 Figma 原橙色卡片独立素材，当前是使用真实分组数据的通用橙卡；完成照暂存/归档有独立限定验收，但未做像素级页面验收 |
| 多区域流程 | `buildFlowZones` 固定一个“收纳区域”，`nativePlan` 仍只执行一个物理区域，无法覆盖 Figma 区域二。先核实真实分区与步骤语义，不能把目的地当物理区域或开启固定演示五步冒充真实完成 |
| AR/工具页路由 | `arPreview`、`tools` 有分支但正常主线直接 `zones → arGuide`；核实最终画板后决定是否接回，不为覆盖旧函数而接入弃用页 |
| 分类页/书籍页/添加弹层 | 已存画布显示不同书籍层级、来源弹层和表单；当前 BooksCategoryScreen 被大量替换，添加拍照会直接进相机，最近物品图标/空态等也有差异。按 `2283:9423` 的 11 张手机逐屏重查，不能只复原 MakePreview 就称 Figma 一致 |
| 空间及重新点亮 | 空间组 `2283:6711` 的 10 张手机尚无完整逐屏近距 + 模拟器比对。compare/same/new、完成照预览/重拍/退出需在最终包实际操作 |
| 个人和项目细节 | 专项已修复，但非全状态像素验收。项目“本周”没有按周筛选，更多只是开详情，完成卡缺完成日期/实际耗时（当前为预算），需要按最终稿补实 |

注意：**检查照片页已经存在**，在 `CaptureStep.previewMode` 中对应 `2261:2105` / `2261:2469`。旧 `ReviewStep` 未挂载，不代表检查页丢失；不要再接一套重复确认页。`ShootFlow.tsx` 中“设计稿没有这屏”的旧注释不准确，适时纠正。Figma 上区黑色可能是原生相机占位，未核实前不要把真实相机/照片删成黑底。

### C. 每个页面的完成证据

1. 同一内容状态下对照正式画板；匹配层级、字体、颜色、间距、图片裁切和固定控件。390 × 844 是多张画板尺寸，但存在长页，应逐张读尺寸。
2. 保留已有 motion/CSS 动画参数，并检查新真实数据路径仍会触发。
3. 更新网页资源，构建/安装实际 App，捕获正确页面。先确认截图不是加载页、过渡态或错页。
4. 实际点击主要操作、返回、弹层和滚动；重启验证持久化。测试数据须隔离、备份，并注明是否恢复。
5. 在 screen map 逐条附证据，未知/缺测就写未验收。浏览器注入状态只证明 Web UI，不能证明 Swift 保存、真机相机或系统分享。

## 7. 尚未完成的功能与质量边界

- 全部 Figma 逐屏还原未完成。完整画板总数尚未最终去重/定版。
- 徽章目录 12 枚，真实规则只有两项：首个完成方案解锁“整洁小浣熊”；5 个已整理空间解锁“闪亮魔法师”。其余 10 项保持锁定，缺事件追踪；真实等级成长未实现。Sarah 身份、加入时间及“4 级”是用户选择的设计展示。
- 帮助与反馈、退出登录只有提示，真实账号/帮助流程未接入。好友、收藏的当前实现也不能据已有组件就视为完整线上社交。
- 普通拍摄面向当前选中空间，创建新空间的完整产品流程尚未验收。
- 上次全量自动测试：**76 个用例，70 通过、6 失败、0 跳过；15 是断言失败数，不是 15 个失败用例。** 本轮没有重跑全量；已有失败涉及原生识别/定位，且识别服务也有改动，没有修改前对照，不能说全是旧问题。
- 引导修复有 15 项 Node 流程测试、390 × 844 模拟 bridge 网页交互测试和 4 项原生进度/归档定向测试，详见[增量报告](docs/design/guide-progress-repair-20261021.md)。完成照修复另有生产网页 smoke、Debug 构建与模拟器相册暂存/归档的限定验收，见本文件第 5 节。不要把局部通过扩写为全 App 或全量回归通过。
- Figma 分类橙色插画素材尚未找到。当前卡片仅恢复数据驱动的结构和操作，不等于逐屏视觉复刻。
- 实际 iOS 模拟器普通主线已验证到待保存完成照并测试重启未归档；完成照选中后的暂存预览和确认后归档另有模拟器相册验收。仍未验证真机相机、原生持久化失败重试、重新点亮完整路线、新流程实际 UI 保存失败回滚或前置 localStorage 跨进程恢复。真机相机、实时帧率、AR、系统分享、VoiceOver、动态字体、多机型和全部离线行为尚未完成验收。
- 6 图对象级：16 个标注目标匹配 11 个（68.75%），平均 IoU 0.643；杂物堆/车库出现 0 候选。不能降低门槛只为变绿。详细失败名称和原因已写入测试报告。
- 最近一次全量 76 项原生测试结果是历史记录，早于完成照修复，本轮没有重跑全量。完成照另有 15 项 guide 逻辑测试、生产 dist 模拟 bridge smoke、iOS Debug 构建和有限模拟器验收；4 项原生定向测试属于此前引导修复，不覆盖本轮全部改动。
- **没有成功安装到用户手机。** 原工作站遇到无线隧道断开、`No Accounts`、`No profiles for com.qszjlzz.smartpaw`。不能把模拟器安装说成手机安装。
- App Store 尚不可提交：开发者账号、模型版权、隐私/支持资料、Xcode 26/iOS 26 SDK 以及真机验收等问题见 [上架背景](docs/app-store/README.md)。不把这些资料草稿当作已发布政策。

## 8. 新电脑如何运行和继续开发

### 网页 UI

需要标准 Node/npm 或 pnpm、Python 3。仓库含 pnpm v9 格式锁文件，推荐 Node 24 LTS 和 pnpm 10；它们是新机建议，不是已验证的唯一组合。只有 `build` script，没有 `dev` script。不要依赖原电脑 Codex runtime 的绝对路径。本轮 `scripts/build-bundled-web.sh` 已兼容检测 npm/pnpm；网页 smoke 脚本的默认输出在仓库 `outputs/`，Chrome 启动失败时也会关闭临时服务。

```sh
cd FigmaMakeLatest-v3
pnpm install --frozen-lockfile
pnpm exec vite --host 127.0.0.1
# 浏览器查看终端输出的本地地址；正常退出服务后返回仓库根目录
```

可以用 `?flow=plandeck`、`?flow=zones`、`?flow=arguide`、`?flow=reward` 或 `?relight=choice` 等已有开发参数查看指定分支，但它们是调试路径，未证明正常用户路线可达；无原生 bridge 时可能使用示例状态。不要把虚拟空间 ID 发给原生保存。

### 更新手机内网页并构建模拟器

```sh
# 在仓库根目录，依赖已安装且 node/npm 在 PATH
sh scripts/build-bundled-web.sh
xcodebuild -list -project SmartPaw.xcodeproj
xcrun simctl list devices available

# 将下面的 YOUR_SIMULATOR_UDID 替换为这台电脑的设备 ID
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -derivedDataPath /tmp/smartpaw-handoff build
xcrun simctl install YOUR_SIMULATOR_UDID /tmp/smartpaw-handoff/Build/Products/Debug-iphonesimulator/SmartPaw.app
xcrun simctl launch YOUR_SIMULATOR_UDID com.qszjlzz.smartpaw
```

原环境为 Xcode 16.4 / iOS 18.5 Simulator；项目最低 iOS 18。新机没有相同 runtime 时选本机可用设备并记录差异。不要复制旧电脑模拟器 UUID。相机模拟器不可用可用仓库 `Resources/ExternalScanTests/` 测试图，通过 `simctl addmedia` 导入后选相册；相册只验证该通道。

测试命令使用相同工程/Scheme，将 build 改为 test，并使用新的 `-resultBundlePath`。全量识别测试旧环境耗时约 22 分钟；纯文档交接无需再跑全量。需要验证方案复用时可选 `testReusingArchivedPlanCreatesIndependentExecutionAndPersistsIt`、`testReusingPlanWriteFailureRestoresSpaceAndExecutionZones`；不要把定向通过扩写成全量通过。

提交门禁：`sh scripts/release-preflight.sh`。这是静态检查；原工作站预期 2 个 FAIL（SDK、AGPL 模型）和 2 个 WARN，不能替代构建/功能/版权或审核。

### 签名和本地配置

App target team 当前为 `46484446VW`，test target 为 `3S323K52DX`；新电脑先在 Xcode 检查证书/账号，再由有权限的开发者配置。不要默默改 team 或签名来假装安装成功。普通接手不要先运行 `scripts/generate_xcodeproj.rb`，它会删除重建工程且带本机 Ruby 查找路径。

`Resources/llm-defaults.json` 被忽略，可能含密钥，本次不传；`.env`、Keychain、证书、描述文件、node_modules、DerivedData、设备照片、模拟器数据库均不随交接迁移。默认本地功能不应依赖原机密钥；可选云端 AI 要由用户在新环境配置并明确同意发送。

## 9. 哪些历史记录需要谨慎解读

- 2026-10-20 文档中的 50/72 项、旧 JS hash、旧截图属于各自当时的构建；以 2026-10-21 测试报告和本交接快照解释当前范围。
- 原专项曾写“dist 未复制”“compare/same/new 未处理”，这些是子任务交付时状态，后续已集成；各文件已加更新说明。
- 原 `/tmp` 日志、xcresult、临时检查脚本和模拟器备份不是仓库材料，交接时其中一些已不存在。已保存的报告是历史结果摘要，不能宣称新电脑重新运行过。
- 原模拟器末次含人为走流程产生的测试照片/计划；原聊天计划的清理恢复尚未得到最终证据。本次不复制这份模拟器数据库，新机从独立状态开始。
- 分支里的所有截图均有状态/时间边界；不要只看图片数量就宣称全流程验收完成。

## 10. 可直接粘给新对话

> 请接手灵爪收纳：仓库 https://github.com/Qszjlzz/LingZhuaShouNa ，切到 `codex/figma-ui-handoff-20261021` 最新提交，先检查 `git status`，完整阅读根目录 `HANDOFF.md`，再读 `docs/design/task-checklist-parity-20261021.md`、`docs/design/completion-flow-parity-20261021.md`、`docs/figma-screen-map.md` 和 `docs/handoff/current-state-20261021.json`。主任务是全部正式 Figma 手机画板与实际 App 逐屏对齐，保留原动效和真实业务，尚未完成。已确认 Sarah Chen 个人页加徽章；第三栏“项目”采用个人分组“我的计划”卡片；不要独立日历；原社区入口由项目替换；沿用 React + WKWebView。详细整理组现已核实 21/21 个 frame 来源及 390×844 尺寸，不代表页面实现或验收完成；`2276:2639` 为桌下数据线整理 Step 3/3。TaskStep 当前按真实 plan step 显示，但 `NativeStep.zone` 是目标归位位置，不是桌面/桌下物理区域；15 项逻辑测试、生产网页模拟 bridge smoke、Debug 构建、iPhone 16 Pro / iOS 18.5 模拟器安装和启动均通过，原生截图只到空间地图。下一步先建立可靠 physical-zone 到 item/plan/step 的真实数据和持久化，再按 Figma 实现区域一 5 项、区域二 3 项清单及逐步引导；也要继续解决微调改变实际步骤、空间/分类/个人/项目的逐屏差异。完成照到地图弹窗最新路线尚未在原生模拟器重走。缺口和测试失败都写在仓库，不要把局部通过或构建成功说成全 App 完成。
