# 资源清单

## 判断原则

- 文本、容器、列表、按钮、导航和简单线性图标优先用 SwiftUI 原生实现。
- 品牌 Logo、独特插画、人物头像、真实空间照片和无法用系统图标准确替代的视觉素材，列为候选导出资源。
- 不能因为某个元素看起来像图片，就把整张手机页面导出成图片。
- 每个导出资源必须记录来源图层、导出格式、尺寸、用途和是否可替换。

## 当前候选资源

| 资源 ID | 类别 | 当前判断 | 来源 | 状态 |
| --- | --- | --- | --- | --- |
| `ASSET-BRAND-001` | Logo/品牌标识 | 候选导出 | Frame 7 中品牌相关图层，待单独选中 | 待确认 |
| `ASSET-ICON-001` | 底部导航图标 | 优先原生 SF Symbols 或独立 SVG | 各页面底部导航 | 待确认 |
| `ASSET-IMG-001` | 空间照片 | 导出/复用真实照片 | 空间、采集、成果页面 | 待确认 |
| `ASSET-IMG-002` | 社区案例图片 | 导出内容资源 | 社区案例列表/详情 | 待确认 |
| `ASSET-ILL-001` | 独特插画/徽章 | 候选导出 | 个人徽章和完成态 | 待确认 |

## 已存在但尚未按单页归属的参考图

这些文件已复制到 `evidence/raw/`，只作为定位证据，待逐页导出后再绑定到页面 ID：

- `FRAME-7-overview.png`

- `capture-*.png`
- `overview.png`
- `center-home-detail.png`
- `far-right-screens.png`
- `tools-pages.png`
- `lower-tools-detail.png`
- `right-result-detail.png`
- `profile-*.png`
- `space/*.png`
