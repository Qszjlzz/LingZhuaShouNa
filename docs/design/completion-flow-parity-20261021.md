# 完成流程对齐与增量验收 · 2026-10-21

本次把整理前后对比页的归档成功路径改为直接回空间地图显示成就弹窗，并按 Figma 简化完成照取景页。**15 项流程逻辑测试、390 × 844 生产网页模拟 bridge 检查和 iOS Debug 构建通过；新包已在模拟器启动到空间地图。最新完成照到地图弹窗的路径尚未在原生模拟器重新走通，全 App 对齐仍未完成。**

接手入口：[HANDOFF.md](../../HANDOFF.md)。本报告对应网页资源 `index-CghoGBxs.js`，指纹及包内一致性结果见 [manifest.json](../handoff/evidence/completion-flow-20261021/manifest.json)。

## 设计依据与画板关系

Figma 文件：[ui界面](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2)。以下节点均已现场选中，尺寸为 390 × 844；截图包含 Figma 画布上下文，不是可嵌入产品的整屏素材。

| 节点 | 核实内容 | 证据 |
| --- | --- | --- |
| `2261:3290` | 完成照取景页：顶部提示条、底部橙色快门 | [原参考](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3290-completion-photo.jpg) |
| `2261:3091` | 完成照右邻、地图成就弹窗左邻；整理前后拖动对比、区域/物品/分钟统计、底部“查看成就” | [选中及尺寸](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3091-before-after-overview.jpg)、[上半页](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3091-before-after-detail.jpg)、[底部按钮](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3091-before-after-bottom.jpg) |
| `2261:5907` | 空间地图遮罩上的成就弹窗，按钮“加入我的家” | [原参考](../../app-analysis/figma-reference/detailed-flow-20261021/2261-5907-achievement-modal.jpg) |
| `2261:3457` | 区域一完成并准备加载下一区域；桌面区域 Step 5/5 | [选中及尺寸](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3457-area-complete-overview.jpg)、[近距](../../app-analysis/figma-reference/detailed-flow-20261021/2261-3457-area-complete-detail.jpg) |
| `2276:1795` | 实际是区域二完成、收纳任务完成；桌下区域 Step 3/3。其图层名仍是“区域1完成”，不可据此合并 | [选中及尺寸](../../app-analysis/figma-reference/detailed-flow-20261021/2276-1795-area-complete-overview.jpg)、[近距](../../app-analysis/figma-reference/detailed-flow-20261021/2276-1795-area-complete-detail.jpg) |

详细整理组现有 11 / 21 个 frame 的身份及尺寸得到独立核实，全部画布顺序和版本关系仍需补齐。这一计数不表示 11 个页面已完成视觉及交互验收。

## 实际修改

- `FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx`：完成照页提示条上移，视觉上保留顶部信息和底部快门；提示条内相机图标可打开相册，左边缘向右滑可退出。手势开始和结束都会检查同步忙碌锁，防止拍照期间退出。
- `RewardStep`：仍先使用 `after-preview` 暂存照片，点击“查看成就”才调用 `capture.after.commit`。成功后播放原来的 8 枚碎片庆祝、等待 660ms，再执行 `onFinish()` 回到空间地图成就弹窗；移除中间额外的独立全屏“这一轮整理完成”卡片。
- 原按钮的 `whileTap: scale 0.96` 和 spring 参数、碎片颜色/距离/时长保留到新位置。此前“54 个 motion 元素属性一致”是较早整理引导快照的证据，本次没有重跑全文件 AST 比较。
- `tests/guide-ui-smoke.mjs`：按新相册入口和归档路由更新检查，验证“加入我的家”弹窗可领取、边缘退出后相机启动不再重试。
- `scripts/build-bundled-web.sh`：重新生成 `Resources/FigmaMakeLatestWeb`。源 dist、仓库内嵌资源及本次 App 包的 JS 和 index 字节相同。

相册入口改到图标、退出改为边缘手势，是保留能力并匹配静态画板的实现选择；真实触摸和可发现性尚未验收。前后对比页仍保留“稍后完成”“重新拍摄”两项操作，不能据本次修改宣称它与 Figma 完全一致。统计中的分钟来自方案预算 `timeBudget`，不是实测用时。

## 本次通过的检查

| 检查 | 结果与范围 |
| --- | --- |
| `pnpm test:guide` | 15 / 15；真实步骤 UUID 推进、前置阶段隔离、失败不推进等 helper 逻辑 |
| `pnpm build` 及内嵌资源同步 | 通过；Vite 有既有的主包大于 500 kB 提示 |
| 生产 dist + 模拟 native bridge | 390 × 844 通过、无页面错误；相册取消、相机/相册暂存、重拍取消、稍后退出、失败重试、防重复提交、确认归档一次、直接打开地图成就弹窗并领取、延迟相机启动退出后不再重试；也覆盖项目和进行中详情的完成照入口 |
| `SmartPaw` scheme / Debug / iPhone 16 Pro / iOS 18.5 | `xcodebuild` 构建成功，安装后启动到空间地图；新包启动截图见下方证据 |
| 资源一致性 | dist、仓库内嵌资源与 App 包的 JS/index 字节相同，见 manifest |

网页回归使用仓库测试照片并注入 bridge；取景截图的空白区域没有真实视频，不能用来判断相机取景效果。真实相册暂存和确认归档的较早模拟器证据见 [completion-photo-20261021](../handoff/evidence/completion-photo-20261021/)，它验证的是当时的原生保存门槛，不是本次新路由的完整原生验收。

本次构建还报告了现有 Swift 并发锁、弃用 API、Asset Catalog / 构建脚本等警告；构建成功不代表这些警告已修复。全量 76 项原生测试未重跑，历史 6 个失败用例仍需按 [原生测试报告](native-test-results-20261021.md) 处理。

## 保存在仓库的证据

目录：[completion-flow-20261021](../handoff/evidence/completion-flow-20261021/)。

- [完成照布局](../handoff/evidence/completion-flow-20261021/web-camera-layout.png)
- [前后对比暂存](../handoff/evidence/completion-flow-20261021/web-before-after-preview.png)
- [归档失败仍可重试](../handoff/evidence/completion-flow-20261021/web-commit-failure.png)
- [归档后地图成就弹窗](../handoff/evidence/completion-flow-20261021/web-map-achievement.png)
- [完整网页检查结果](../handoff/evidence/completion-flow-20261021/web-smoke-result.json)
- [最新包模拟器启动](../handoff/evidence/completion-flow-20261021/native-launch-space.png)

## 新电脑复跑

使用本机正常安装的 Node、pnpm、Playwright 和 Chrome，避免依赖原工作站 Codex runtime 绝对路径。若项目依赖未包含 Playwright，可先在仓库外建临时工具目录并安装，再用 `NODE_PATH` 指向该目录的 `node_modules`；不要为复跑静默改动项目锁文件。

```sh
cd FigmaMakeLatest-v3
pnpm install --frozen-lockfile
pnpm test:guide
pnpm build
SMARTPAW_CHROME_PATH='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
SMARTPAW_EVIDENCE_DIR=/tmp/smartpaw-completion-flow-smoke \
node tests/guide-ui-smoke.mjs
cd ..
sh scripts/build-bundled-web.sh
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' build
```

新电脑应将 destination 改成本机可用模拟器并记录差异；不要复制原机模拟器 UUID。

## 尚未完成与接续顺序

1. 在最新原生包重走完成照 → 暂存对比 → 失败/重试 → 确认归档 → 地图弹窗 → 领取，并实测相机图标相册入口、重拍/取消、真实触摸边缘退出。真机相机和原生写入失败仍需独立测试。
2. 核实详细整理组剩余 10 个 frame 的实际用途、位置和尺寸，优先 `2276:1531`、`2277:32`；不要从图层名推断用途。
3. 先建立真实照片双物理区域及步骤归属，再实现区域一完成 → 区域二执行 → 区域二完成。现有 `buildFlowZones` 是单物理区域，不能靠目的地标签或演示数据声称覆盖双区域。
4. 使微调聊天真正改变执行步骤；继续补齐分类插画、空间组、分类组及个人/项目各状态的同尺寸原生截图与交互证据。

当前不具备全 App 功能完成、全 Figma 还原、手机安装完成或 App Store 可提交的结论。
