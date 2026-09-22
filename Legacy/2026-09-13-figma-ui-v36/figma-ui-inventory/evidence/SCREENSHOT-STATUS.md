# 截图状态

## 可直接用于视觉比对

| 页面 ID | 文件 | 类型 | 尺寸/说明 |
| --- | --- | --- | --- |
| `SPW-EXE-002` | `screens/SPW-EXE-002-figma.png` | Figma 独立导出 | PNG，2200 x 4016，4x |

## Figma Make 本地预览单页图

以下图片来自已下载的 Make 源码本地预览，并使用手机容器裁切为 `390 x 844`。它们不包含 Figma 工作区，适合审阅代码当前呈现的单页结构；它们不是原始 `ui界面` Frame 7 的 Figma 独立导出。

| 页面 ID | 文件 | 类型 | 说明 |
| --- | --- | --- | --- |
| `SPW-MAKE-SPC-001` | `figma-make-screens/SPW-MAKE-SPC-001-preview.png` | Make 预览裁切 | 空间首页 |
| `SPW-MAKE-CAT-001` | `figma-make-screens/SPW-MAKE-CAT-001-preview.png` | Make 预览裁切 | 分类首页 |
| `SPW-MAKE-COM-001` | `figma-make-screens/SPW-MAKE-COM-001-preview.png` | Make 预览裁切 | 社区列表 |
| `SPW-MAKE-PRO-001` | `figma-make-screens/SPW-MAKE-PRO-001-preview.png` | Make 预览裁切 | 个人主页 |
| `SPW-MAKE-CAP-001` | `figma-make-screens/SPW-MAKE-CAP-001-preview.png` | Make 预览裁切 | 拍摄初始态 |
| `SPW-MAKE-CAP-002` | `figma-make-screens/SPW-MAKE-CAP-002-preview.png` | Make 预览裁切 | 已拍摄一张 |
| `SPW-MAKE-CAP-003` | `figma-make-screens/SPW-MAKE-CAP-003-preview.png` | Make 预览裁切 | 采集预览 |
| `SPW-MAKE-CAP-004` | `figma-make-screens/SPW-MAKE-CAP-004-preview.png` | Make 预览裁切 | 识别确认/盲区处理 |

## SwiftUI Version 36 基座验证

当前默认 Make 基座及其可达真实功能页统一使用英文可见文案；中文仅保留在内部数据/识别兼容层。以下截图仍是功能验证证据，重新截取时应以英文 UI 为准。

以下截图来自当前 App 的原生 SwiftUI 新前端，不是整页图片贴图：

| 页面 ID | 文件 | 类型 | 说明 |
| --- | --- | --- | --- |
| `SPW-MAKE-SPC-002` | `checks/SPW-MAKE-SPC-002-functional.png` | iPhone 16 模拟器 | Spatial，真实空间数据和图片 |
| `SPW-MAKE-CAT-002` | `checks/SPW-MAKE-CAT-002-functional.png` | iPhone 16 模拟器 | Classification，真实搜索/分类入口 |
| `SPW-MAKE-COM-003` | `checks/SPW-MAKE-COM-003-functional.png` | iPhone 16 模拟器 | Community，真实案例数据和操作 |
| `SPW-MAKE-PRO-002` | `checks/SPW-MAKE-PRO-002-functional.png` | iPhone 16 模拟器 | Mine，真实统计和功能入口 |

### English UI final checks

These screenshots are the final English-language checks for the current Make-based native SwiftUI front end. They are captured after the app is launched with the corresponding debug route and do not include a Figma device shell.

| 页面 ID | 文件 | 说明 |
| --- | --- | --- |
| `SPW-MAKE-SPC-003` | `checks/SPW-MAKE-SPC-003-english.png` | Spatial，英文首页 |
| `SPW-MAKE-CAT-003` | `checks/SPW-MAKE-CAT-003-english.png` | Classification，英文分类页 |
| `SPW-MAKE-COM-004` | `checks/SPW-MAKE-COM-004-english.png` | Community，英文社区列表页 |
| `SPW-MAKE-COM-005` | `checks/SPW-MAKE-COM-005-header-alignment.png` | Community，标题、筛选栏与内容卡片左边界对齐 |
| `SPW-MAKE-COM-006` | `checks/SPW-MAKE-COM-006-spacing-fixed.png` | Community，修复卡片之间异常的底部留白 |
| `SPW-MAKE-MIN-003` | `checks/SPW-MAKE-MIN-003-english.png` | Mine，英文个人页 |
| `SPW-MAKE-CAP-005` | `checks/SPW-MAKE-CAP-005-safe-area-fixed.png` | Capture，顶部控件避开 Dynamic Island |

### Language flow checks

| 页面 ID | 文件 | 说明 |
| --- | --- | --- |
| `SPW-LANG-002` | `checks/SPW-LANG-002-picker.png` | 原有启动画面结束后的首次语言选择页 |
| `SPW-LANG-005` | `checks/SPW-LANG-005-chinese-home.png` | 选择中文后的 Spatial 首页 |
| `SPW-LANG-006` | `checks/SPW-LANG-006-settings-zh.png` | 个人页进入的语言设置页，中文已选中 |

### Profile avatar parity check

| 页面 ID | 文件 | 说明 |
| --- | --- | --- |
| `SPW-MAKE-MIN-005` | `checks/SPW-MAKE-MIN-005-avatar.png` | Mine，使用原生 SwiftUI 浣熊头像并调整个人信息间距 |

黑色 Dynamic Island 与底部 Home Indicator 属于 iOS 模拟器系统安全区；App 没有添加 Figma 网页预览的手机外壳、黑色四角或整页截图容器。

## 可用于页面定位和流程确认

以下文件是 Chrome 中 Figma 画布的聚焦截图，保留了左右相邻画板和图层面板，适合确认页面关系，不适合直接做像素级差异计算：

- `evidence/crops/SPW-CAP-001-figma-canvas.png`
- `evidence/crops/SPW-CAT-001-figma-canvas.png`
- `evidence/crops/SPW-CAT-003-figma-canvas.png`
- `evidence/crops/SPW-EXE-002B-figma-canvas.png`
- `evidence/crops/SPW-EXE-002C-figma-canvas.png`
- `evidence/crops/SPW-EXE-002D-figma-canvas.png`
- `evidence/crops/SPW-EXE-003-figma-canvas.png`
- `evidence/crops/SPW-EXE-005-figma-canvas.png`
- `evidence/crops/SPW-PLN-004-figma-canvas.png`

## 导出限制

当前 Figma Chrome 会显示教育身份验证提示，页面可查看和部分导出，但批量导出按钮不稳定。没有成功写入本地的页面不标记为“独立导出完成”。
