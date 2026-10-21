# Figma Screen Map

Source: `ui界面` (`cHyKGPXFlSnNcjBWw9MNxE`)

Latest handoff: [HANDOFF.md](../HANDOFF.md). The full Figma audit is incomplete; see [inventory](design/figma-full-inventory-20261021.md), [ShootFlow differences](design/shootflow-parity-20261021.md), and the [completion-flow parity report](design/completion-flow-parity-20261021.md). Entries below retain historical evidence and are not a full-app parity claim.

## Processing rule

Process complete phone frames from the canvas top row to bottom row, left to right. A text layer named `分类`, `拍摄`, or `执行` is not itself a screen; the surrounding 390 x 844 frame is the unit of implementation.

## Historical First-row Records

These are early mapping notes, not the verified canvas order. The `/tmp` and `Documents` references are historical local files and do not travel with a GitHub clone. The newer node-based records below supersede their screen identities where explicitly stated.

| Order | Screen | Evidence | App route | Status |
| --- | --- | --- | --- | --- |
| 1 | Earlier label: 拍摄/扫描完成照片 | Desktop Figma `ShootFlow`, 390 x 844 frame | `RootView → CurrentFigmaMakeWebView → ShootFlow` | The old label does not establish a completion-photo frame. The selected Figma `ShootFlow` node `2354:32` is actually the item-classification guide; see the inventory. Earlier native `CaptureView` evidence is historical. |
| 2 | 对比整理前后 | Verified Figma node `2261:3091`; see the design reference below | `RewardStep` staged after-photo comparison → commit → `SpatialScreen` achievement modal | Design identity and visible CTA confirmed. The comparison is shown before archive; browser production-flow smoke reaches the map modal after commit. Native simulator has not replayed this latest route or confirmed visual parity. |
| 3 | Earlier label: 区域完成 / 新徽章 | `/Users/qszjlzz/Documents/Container.png` | `-SmartPawShowCompletion` (historical prototype) | Native prototype build evidence only; not the live React route or current Figma parity. Current verified design-source node `2261:5907` is listed below. |

Record design-source identity separately from app acceptance. A selected Figma frame confirms what the design contains; only a matching runtime capture establishes implementation parity.

## Detailed Flow: Verified Design Sources

Source group: `2261:6479`. These entries record eleven selected Figma frames and their saved design references, separately from implementation acceptance. All eleven selected frames show 390 x 844. Canvas order for all 21 frame children is still incomplete. See the [inventory corrections](design/figma-full-inventory-20261021.md#近距选中后的用途修正) for visible controls, position relationships and the remaining audit boundary.

| Figma node | Actual screen/state | App route/state | Design reference | Implementation status |
| --- | --- | --- | --- | --- |
| `2261:5717` | 快速整理方案 | `ShootFlow: plandeck → PlanDeckStep` | [Plan](../app-analysis/figma-reference/detailed-flow-20261021/2261-5717-plan-quick.jpg) | Design-source identity verified; same-state simulator comparison pending. Current component selects `plans[0]`; the right-side arrow's intended action remains to be verified. |
| `2261:6249` | 方案微调聊天 | `ShootFlow: tune` | [Plan tuning](../app-analysis/figma-reference/detailed-flow-20261021/2261-6249-plan-tuning-chat.jpg) | Design-source identity verified. Current confirmation changes the plan name/vibe, not real execution steps; same-state comparison and real-step edit behavior pending. |
| `2261:3989` | 选择整理分区，未选区 | `ShootFlow: zones → ZoneSelectStep` | [No zones selected](../app-analysis/figma-reference/detailed-flow-20261021/2261-3989-zones-unselected.jpg) | Design-source identity verified; the start action is disabled. The actual app currently has no physical-region segmentation model. |
| `2261:3719` | 选择整理分区，桌面区域选中 | `ShootFlow: zones → ZoneSelectStep` | [Selected zones](../app-analysis/figma-reference/detailed-flow-20261021/2261-3719-zones-selected.jpg) | Its layer name “方案生成” is misleading. Figma shows two physical zones; current fixed single-zone model does not cover it. Full parity pending. |
| `2285:11376` | 识别加载 | `ShootFlow: generating → GeneratingStep`, recognition phase | [Recognition loading](../app-analysis/figma-reference/detailed-flow-20261021/2285-11376-recognition-loading.jpg) | A complete loading state, previously mistaken for a sketch. Same-state simulator and runtime-stage verification pending. |
| `2285:11580` | 正在规划整理方式 | `ShootFlow: generating → GeneratingStep`, planning phase | [Planning loading](../app-analysis/figma-reference/detailed-flow-20261021/2285-11580-planning-loading.jpg) | A second loading state, not an alternate plan sketch. Same-state simulator and runtime-stage verification pending. |
| `2261:3290` | 拍摄整理完成照 | `ShootFlow: reward → RewardStep`, capture state | [Completion photo](../app-analysis/figma-reference/detailed-flow-20261021/2261-3290-completion-photo.jpg) | Full-screen camera view with completion-photo prompt and orange shutter. Latest code preserves the capture/retake flow and returns to the spatial map after archive; production build plus simulated native bridge passed the route smoke. iOS Debug installed and launched to the map, but the latest capture-to-map route was not replayed in the native simulator. Real-camera, touch-swipe, and visual parity remain pending. See [completion-flow evidence](handoff/evidence/completion-flow-20261021/) and [report](design/completion-flow-parity-20261021.md). |
| `2261:3091` | 对比整理前后 | `RewardStep` staged after-photo comparison → commit → `SpatialScreen` achievement modal | [Before/after comparison](../app-analysis/figma-reference/detailed-flow-20261021/2261-3091-before-after-overview.jpg) | Confirmed adjacent to the right of `3290` and left of `5907`. The comparison UI is present after staging the after photo and before archive. It shows completion label, draggable before/after photos, area/item/minute stats, and bottom CTA “查看成就”. The minute value is a plan estimate, not measured elapsed time. Production-flow browser smoke reached the map modal after commit; latest native route and visual parity remain pending. See [completion-flow report](design/completion-flow-parity-20261021.md). |
| `2261:3457` | 区域一完成，加载下一区域 | `ARGuideStep` completion candidate | [Area completion](../app-analysis/figma-reference/detailed-flow-20261021/2261-3457-area-complete-overview.jpg) | Confirmed as desktop area Step 5/5 with a dimmed photo, green completion marker, and next-area loading message. Current app has no verified multi-area route; same-state implementation and runtime parity remain unverified. |
| `2276:1795` | 区域二完成 / 收纳任务完成 | `ARGuideStep` completion candidate | [Area completion](../app-analysis/figma-reference/detailed-flow-20261021/2276-1795-area-complete-overview.jpg) | Layer is misleadingly named “区域1完成”; selected image shows under-desk cable area Step 3/3 and task completion. Current app has no verified multi-area route; same-state implementation and runtime parity remain unverified. |
| `2261:5907` | 空间地图遮罩上的成就弹窗 | `ShootFlow: reward → RewardStep` celebration → `SpatialScreen` achievement modal | [Achievement modal](../app-analysis/figma-reference/detailed-flow-20261021/2261-5907-achievement-modal.jpg) | Figma shows a dimmed map, achievement illustration, and “加入我的家”; preceding comparison frame CTA says “查看成就”. The added standalone full-screen completion page was removed; after archive, original fragment celebration plays and returns to the map modal. Browser production-flow smoke passed; latest native route and visual parity remain pending. See [completion-flow report](design/completion-flow-parity-20261021.md). |

The new references are browser canvas screenshots with surrounding Figma UI, not exported artboards. Their selection outline and size label establish the frame identity and dimensions; they are not a substitute for native screenshots or exact typography/spacing measurements. The selected Figma sources remain read-only.

## Personal And Project Modules

Source: `ui界面`, `Page 1`, the phone-frame group adjacent to the visible canvas label `个人`. The selected profile is Sarah Chen. The nearby `已完成空间` gallery is a separate Space screen and is excluded. The user confirmed that the third bottom-navigation item is `项目`, and that it contains the `我的计划` design; the separate calendar screen is intentionally not part of the app flow.

| Order | Figma screen | App route/state | Main actions | Status |
| --- | --- | --- | --- | --- |
| 1 | 个人主页 | `MineScreen` | Open shared project tab, badges, saved posts, friends and settings; help/logout show demo notices | Sarah Chen and Figma original avatar retained. Native statistics and earned badges now read real state; seven earned badges are only browser-preview fixtures. Final native screenshot: `verified-20261021/simulator/final-profile-earned.png` (4 items / 1 space / 1 badge). Identity and level label remain design content. |
| 2 | 徽章 | `BadgesScreen` | Filter all/earned/locked; open a badge | Gallery opened in simulator; `simulator/badges.png`; original motion nodes retained. |
| 3 | 徽章详情：已获得 | `BadgesScreen` overlay | Close or share | Open/close and layer above bottom nav verified; `simulator/badge-earned.png`. Share action not part of this runtime check. |
| 4 | 徽章详情：未获得 | `BadgesScreen` overlay | Close; inspect unlock progress | Open/close, progress and layer verified; `simulator/badge-locked.png`. |
| 5 | 我的计划 | Bottom tab `project` → `MyPlansScreen` | Filter plans, pause/resume, open details; existing step/completion-photo actions retained | Figma plan card structure restored; no calendar route/button. Pause/resume and restart persistence verified with disposable fixtures, then original simulator data restored. |

The schedule records remain visible and actionable in the project list. `CalendarScreen.tsx` is currently not imported by any app route, so its separate month-grid artboard is not reachable. The app remains a WebView-backed React flow (`RootView → CurrentFigmaMakeWebView → Resources/FigmaMakeLatestWeb`), not six independent SwiftUI states.

Unless explicitly prefixed with `verified-20261021`, evidence paths above are relative to `app-analysis/figma-reference/verified-20261020/`. See [personal/project verification](design/personal-project-figma-verification-20261020.md) for the historical tests, fixture restoration and later native-data changes. Latest full native result: 76 test cases, 70 passed and 6 failed (15 failed assertions); see [test diagnosis](design/native-test-results-20261021.md). It does not cover all final edits or establish whole-app UI parity.
