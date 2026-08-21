# Figma Screen Map

Source: `ui界面` (`cHyKGPXFlSnNcjBWw9MNxE`)

## Processing rule

Process complete phone frames from the canvas top row to bottom row, left to right. A text layer named `分类`, `拍摄`, or `执行` is not itself a screen; the surrounding 390 x 844 frame is the unit of implementation.

## First-row records

| Order | Screen | Evidence | App route | Status |
| --- | --- | --- | --- | --- |
| 1 | 拍摄/扫描完成照片 | Desktop Figma `ShootFlow`, 390 x 844 frame | `CaptureView` | Native route aligned; top mode switch, countdown HUD, stable white action panel verified |
| 2 | 对比整理前后 | `/tmp/figma-first-row.png`, middle phone | pending | pending |
| 3 | 区域完成 / 新徽章 | `/Users/qszjlzz/Documents/Container.png` | `-SmartPawShowCompletion` | Native prototype built |

Each row must be updated only after its matching Figma frame is selected and its simulator screenshot is captured.

## Personal Module Inventory

Source: `ui界面`, `Page 1`, the phone-frame group adjacent to the visible canvas label `个人`. Verified at 25% and 50% canvas zoom. The nearby `已完成空间` gallery is a separate Space screen and is excluded.

| Order | Figma screen | Purpose | Main actions |
| --- | --- | --- | --- |
| 1 | 个人主页 | Sarah Chen profile, three stats, a five-badge strip, account rows | 我的计划, 已保存的帖子, 关联好友 |
| 2 | 徽章 | 7/12 achievement gallery with filters and rarity key | Open any badge |
| 3 | 徽章详情：已获得 | Dims the gallery and presents an earned badge with date/share | Close, share badge |
| 4 | 徽章详情：未获得 | Same overlay structure, with locked progress | Close |
| 5 | 我的计划 | Weekly activity count, plan filters, plan cards and progress | Mark/continue a plan, view calendar |
| 6 | 日程 | Month calendar, selected-day empty state, upcoming plans | Navigate back, add plan |

Implementation rule: these six artboard states map to six independent SwiftUI states. Do not substitute the older `收纳等级 Lv.3` profile prototype or merge the badge overlays into a generic detail page.
