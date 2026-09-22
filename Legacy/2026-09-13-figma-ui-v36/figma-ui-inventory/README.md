# Figma UI 页面资产库

本目录用于把 Figma 文件 `ui界面` 拆成可审阅、可实现、可验收的独立手机页面。

## 当前范围

- 来源文件：`ui界面`
- 来源文件 ID：`cHyKGPXFlSnNcjBWw9MNxE`
- 当前重点：`Frame 7`
- 标准手机画板：优先按 `390 x 844 pt` 记录；超长页面另记滚动高度。
- 当前阶段：建立页面清单、截图证据和流程关系，尚未开始新的 SwiftUI 视觉重做。

## 目录

| 目录 | 用途 |
| --- | --- |
| `screens/` | 每个独立页面的最终裁切图，文件名使用页面 ID。 |
| `figma-make-screens/` | 从 Figma Make 本地预览裁切的单页参考图，一张图对应一个手机界面。 |
| `screen-records/` | 每页一个 Markdown 记录，说明用途、入口、出口、状态和视觉规格。 |
| `flows/` | 页面之间的导航关系、主流程和底部导航约定。 |
| `assets/` | 从 Figma 导出的独立 Logo、图标、插画和照片资源。 |
| `figma-make-code/` | Figma Make 下载的 React/TypeScript/Vite 源码和附带资源，作为 SwiftUI 转换参考。 |
| `evidence/raw/` | 已有的 Figma 组合截图或原始参考图，不作为单页最终证据。 |
| `evidence/crops/` | 当前存放画布聚焦截图和临时裁切证据，直到用 Figma 单独导出替换。 |
| `checks/` | Figma 与模拟器截图的对照记录和验收结果。 |

全局视觉 Token 的初始证据见 `VISUAL-TOKENS.md`。

## 页面记录规则

每个页面使用一个稳定 ID，例如 `SPW-CAP-001`。ID 一旦分配不复用；页面名称可以修订。

页面记录必须回答：

1. 这页的目的和用户任务是什么。
2. 从哪个页面进入，完成什么动作后去哪个页面。
3. 是否有底部导航；当前选中哪个 Tab。
4. 页面是固定高度、可滚动还是底部弹层/覆盖态。
5. 哪些内容用 SwiftUI 原生实现，哪些内容需要从 Figma 导出资源。
6. Figma 截图、SwiftUI 截图和最后一次差异修复分别在哪里。

## 证据状态

- `待单独选中`：已从设计稿语义或组合图推断出页面，但还没有单独选中 Figma 画板。
- `已单独选中`：已在 Figma 中选中并记录尺寸、画面和图层信息。
- `已保存画布证据`：已保存包含 Figma 工作区的定位截图，画板内容可复核。
- `已导出截图`：已有对应的独立 Figma 截图。
- `待实现`：页面资料已齐，可以开始 SwiftUI 实现。
- `对照中`：已有 SwiftUI 截图，正在逐项修正。
- `通过`：视觉和主要交互都完成验收。

## 重要边界

Frame 7 是设计总览画板，不是一个 App 页面。手机画板才是实现单元；分类标题、模块标题和装饰文字不能单独当作页面。组合截图只用于定位和取证，不能直接嵌入 App 作为页面 UI。

## 当前证据

- Frame 7 当前视口总览：`evidence/raw/FRAME-7-overview.png`
- 已命名页面证据：`evidence/NAMED-PAGES.md`
- 该图用于确认总览画板和分组，不代表单页截图已经完成。

## Figma Make 代码检查

已用桌面版 Figma 打开 `Global Style Setup`，确认存在 `Preview / Code` 视图，并成功下载源码。检查结论与单页截图索引见 `evidence/FIGMA-MAKE-CODE.md`。Make 预览图是代码当前状态的参考证据；原始 `ui界面` Frame 7 的页面仍以 Figma 节点和独立导出为最终视觉基准。
