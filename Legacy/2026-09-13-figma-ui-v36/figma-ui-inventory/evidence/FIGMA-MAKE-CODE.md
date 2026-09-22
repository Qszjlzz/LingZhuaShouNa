# Figma Make 代码检查记录

检查日期：2026-08-21

## 来源与保存位置

- Make 项目：[Global Style Setup](https://www.figma.com/make/Ke245Sd2SYA9q9bLV69e66/Global-Style-Setup?t=T2R8LRBuBJDRyMSo-1)
- Figma 桌面端可以打开该项目，并切换 `Preview / Code`。
- 源码包：`/Users/qszjlzz/Downloads/Global Style Setup.zip`
- 解压目录：`figma-ui-inventory/figma-make-code/`
- 项目版本：Figma Make `Version 36`

## 代码结论

- 框架：React + TypeScript + Vite。
- 入口：`src/app/App.tsx`。
- 根级 Tab：`spatial`、`classification`、`community`、`mine`。
- 根级覆盖流程：`ShootFlow`，从底部中央相机按钮打开。
- 主要组件：`SpatialScreen`、`ClassificationScreen`、`CommunityScreen`、`MineScreen`、`ShootFlow`、`BottomNav`。
- 其他已提供但不一定从根入口直接到达的页面组件包括分类详情、空间详情、方案、工具、徽章、好友、日程、社区详情和前后对比。
- Figma Make 的 `Download code` 已成功保存；当前验证提示会禁用在线编辑和部分 AI 操作，但不影响源码读取。

## 可直接迁移的视觉依据

入口代码明确使用 `390 x 844` 手机内容区、`48` 外框圆角、暖色外层背景和深色外框阴影。组件主题文件给出：

| Token | 值 | 用途 |
| --- | --- | --- |
| `COFFEE` | `#7B5C48` | 主文字、棕色图标 |
| `ORANGE` | `#FA883A` | 主按钮、进度和选中态 |
| `LINEN` | `#F6F1EB` | 页面背景 |
| `BLUE` | `#B4C7DC` | 次级状态 |
| `SOFT` | `#EFE6DC` | 分隔线、弱背景 |
| `WHITE` | `#FFFFFF` | 卡片和底部导航 |

底部导航由 `BottomNav.tsx` 统一实现，使用 lucide 图标；导航本身是白色、`32px` 圆角浮层，中央相机按钮为橙色 `64px` 圆形按钮。

## 单页截图

这些图片来自本地 Vite 预览的手机容器裁切，不包含 Figma 工具栏、对话面板或画布周边。图片只用于记录 Make 代码当前的视觉状态，不能替代原始 Figma Frame 的独立导出。

| ID | 页面/状态 | 文件 | 关系 |
| --- | --- | --- | --- |
| `SPW-MAKE-SPC-001` | Spatial 空间首页 | `figma-make-screens/SPW-MAKE-SPC-001-preview.png` | 根入口，默认 Tab |
| `SPW-MAKE-CAT-001` | Classify 分类首页 | `figma-make-screens/SPW-MAKE-CAT-001-preview.png` | 底部导航进入 |
| `SPW-MAKE-COM-001` | Community 社区列表 | `figma-make-screens/SPW-MAKE-COM-001-preview.png` | 底部导航进入 |
| `SPW-MAKE-PRO-001` | Mine 个人主页 | `figma-make-screens/SPW-MAKE-PRO-001-preview.png` | 底部导航进入 |
| `SPW-MAKE-CAP-001` | 拍摄初始态 | `figma-make-screens/SPW-MAKE-CAP-001-preview.png` | 空间首页 -> 相机 |
| `SPW-MAKE-CAP-002` | 已拍摄一张的采集态 | `figma-make-screens/SPW-MAKE-CAP-002-preview.png` | 拍摄初始态 -> 快门 |
| `SPW-MAKE-CAP-003` | 采集预览确认 | `figma-make-screens/SPW-MAKE-CAP-003-preview.png` | 采集态 -> 完成 |
| `SPW-MAKE-CAP-004` | 识别确认/盲区处理 | `figma-make-screens/SPW-MAKE-CAP-004-preview.png` | 采集预览 -> 确认并识别 |

## 资源判断

- 原生实现：文字、布局、卡片、进度、按钮、Tab、导航、lucide 图标和简单插画。
- 需要绑定资源：空间照片、社区案例照片、拍摄背景图、前后对比图、品牌 Logo 和商品图。
- 当前 Make 组件大量使用 Unsplash 远程 URL；SwiftUI 版本不能把远程 URL 当作最终交付资源，应下载并审核后放入 App bundle，或替换为用户确认过的 Figma 独立导出资源。
- `src/imports/` 中的 PNG/JPG 是 Make 项目附带的独立资源或历史参考图，必须逐个核对用途，不把整张手机截图嵌入 App。

## 当前限制

Make 根入口没有把源码中的所有子页面都接成可从首页连续走通的路由；截图清单因此区分“根入口可达”与“源码存在”。后续 SwiftUI 实现应继续以 `SCREEN-INDEX.md` 的 Figma 页面 ID 为主，以这些 Make 组件作为结构和 Token 参考。

## SwiftUI 新基座状态（2026-08-22）

- 当前默认首页使用 `App/MakeReplicaViews.swift`，按 Version 36 的 Spatial、Classification、Community、Mine 结构实现。
- 页面使用原生 SwiftUI 布局、`Button`、`TextField`、`ScrollView` 和真实 `AppViewModel` 数据；没有把 Make/Figma 手机截图嵌入 App。
- 空间卡片进入现有 `SpaceView`，分类进入现有 `CatalogView`/`CaptureView`，社区进入详情、评论、收藏、点赞和复刻流程，Mine 进入计划、徽章和保存帖子页面。
- Figma Make 源码里的手机预览壳只用于网页展示，不能迁移到 App。模拟器截图中的 Dynamic Island/Home Indicator 是系统元素，不属于 App 设计。
- 英文版显示已统一：Make 首页、Capture、Catalog、Community、Space、Execution、Profile、Plans、Badges、Saved Posts 和 Schedule 的用户可见文案均为英文；模型中的中文原值只用于已有数据和识别兼容，并通过 `App/EnglishDisplay.swift` 映射到英文展示。
