# Figma Screen Map

Source: `ui界面` (`cHyKGPXFlSnNcjBWw9MNxE`)

Latest handoff: [HANDOFF.md](../HANDOFF.md). The full Figma audit is incomplete; see [inventory](design/figma-full-inventory-20261021.md) and [ShootFlow differences](design/shootflow-parity-20261021.md). Entries below retain historical evidence and are not a full-app parity claim.

## Processing rule

Process complete phone frames from the canvas top row to bottom row, left to right. A text layer named `分类`, `拍摄`, or `执行` is not itself a screen; the surrounding 390 x 844 frame is the unit of implementation.

## First-row records

| Order | Screen | Evidence | App route | Status |
| --- | --- | --- | --- | --- |
| 1 | 拍摄/扫描完成照片 | Desktop Figma `ShootFlow`, 390 x 844 frame | `RootView → CurrentFigmaMakeWebView → ShootFlow` | Earlier native `CaptureView` evidence is historical; current route uses the bundled React flow and native camera bridge. Full frame parity has not been reverified here. |
| 2 | 对比整理前后 | `/tmp/figma-first-row.png`, middle phone | pending | pending |
| 3 | 区域完成 / 新徽章 | `/Users/qszjlzz/Documents/Container.png` | `-SmartPawShowCompletion` | Native prototype built |

Each row must be updated only after its matching Figma frame is selected and its simulator screenshot is captured.

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
