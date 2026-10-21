# 个人与项目画板核对（2026-10-20）

本记录来自在 Figma `ui界面` / `Page 1` 的实际画布核对，以及项目中保留的原版 React 源码。下文记录本次个人页、徽章和项目的实现与验收范围，不代表全 App 已通过验收。

交接更新（2026-10-21）：后文保留各子任务交付时状态；“本轮没有安装/复制”不能代表最终集成状态。主任务随后打包 `index-Bm7H3tNW.js`、编译安装并有限验证普通整理主流程，最终个人页真实统计为 4/1/1。相关截图、测试及仍未验收项见 [HANDOFF.md](../../HANDOFF.md)。身份/等级展示、其余十枚徽章规则和全部画板一致性依旧不在已完成范围。

## 用户确认

- 个人主页采用 Sarah Chen 版，旧「收纳等级 Lv.3」版排除。
- 补齐徽章墙以及已获得、未获得详情状态。
- 原有动效必须保留。
- 底部原「社区」入口改为「项目」，内容采用个人分组里的「我的计划」设计。
- 日历页面和进入日历的路径移除；其余已确认页面继续依据 Figma。

## 画布顺序和来源

个人分组从左至右为：个人主页 → 徽章墙 → 已获得徽章详情 → 我的计划 → 日历 → 已保存的帖子。未获得徽章详情位于已获得详情的下方。

- Sarah Chen 文本节点：[115:19690](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=115-19690)。这是文本层定位链接，不是完整手机画板 ID。
- 未获得徽章完整手机画板：[2284:10536](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2284-10536)。画布选中状态显示 390 × 844。
- 其他画板通过相邻位置直接核实，未读取到独立节点 ID，不填猜测值。

## 截图证据

截图目录：`app-analysis/figma-reference/verified-20261020/`。裁图只用于比对，不应作为整屏 UI 嵌入 App。

| 文件 | 内容 | 限制 |
| --- | --- | --- |
| `my-plans-phone.jpg` | 我的计划完整手机稿，75% 缩放 | 308 × 648，含手机框；没有工具栏遮挡 |
| `my-plans-75pct-clean.jpg` | 我的计划与相邻徽章画板的画布上下文 | Figma 工具栏遮挡相邻徽章画板底部 |
| `badge-earned-clean-phone.jpg` | 已获得徽章完整手机稿，75% 缩放 | 包含画布的选中参考线；详情和底栏均可见 |
| `badge-locked-phone.jpg` | 未获得徽章完整手机稿，75% 缩放 | 包含画布的选中参考线；详情和底栏均可见 |
| `personal-earned-state-75pct.jpg` | Sarah Chen、徽章墙、已获得详情的相邻关系 | 工具栏挡住个人页及徽章墙下方 |
| `profile-phone-50pct.jpg` | Sarah Chen 个人页全长稿 | 205 × 554，姓名文本有选中高亮，不适合像素级字体比对 |
| `personal-group-50pct.jpg` | 个人分组、计划、日历和收藏的顺序 | 工具栏遮挡相邻部分，仅用于定位 |

较早的 `badge-earned-phone.jpg` 底部被工具栏遮挡，后续优先使用 `badge-earned-clean-phone.jpg`。

## 我的计划稿

- 亚麻色背景，白色圆形返回，居中「我的计划」，右侧橙色添加按钮。迁至 Tab 根页时标题按项目入口语义调整，返回按钮按路由处理。
- 棕色渐变摘要卡：「本周」「3 个活动计划」「4 小时 27 分钟预定」。右侧原日历按钮按用户要求移除。数值以真实业务状态计算。
- 筛选文案：全部 / 活跃的 / 预定的 / 完成。
- 进行中：迷你公寓衣柜，卧室，35%，暂停按钮。
- 已暂停：5 分钟厨房重置，厨房，60%，继续按钮。
- 已安排：周末客厅重置，客厅，时间说明，无进度条。
- 已完成：餐具室深度清洁，厨房，完成日期和用时，无进度条。
- 图片贴合卡片左上边缘；进行中/暂停卡片的进度条位于整张卡片下部，跨越图片下方与内容区。当前修改时不能误放成只占右侧内容栏的细进度条。
- 本地已有独立内容素材：`Resources/Assets.xcassets/FigmaProfilePlanCloset.imageset/closet.png`、`FigmaProfilePlanCabinet.imageset/cabinet.png`、`FigmaProfilePlanLiving.imageset/living.png`。

## Sarah Chen 和徽章稿

- 个人稿：白色背景，浣熊圆形头像，Sarah Chen，@sarah · 于 2026 年 5 月加入，4 级 · 整洁大师。三列统计和五枚可见徽章条，下接我的计划、已保存的帖子、关联好友等行。Figma 示例统计为 248 / 12 / 7；实际运行数据与示例数据须分清。
- 徽章墙：棕色渐变 hero，钻石展示，7 / 12 示例计数与进度条；全部 / 已获得 / 已锁定筛选；三列网格；稀有度图例。
- 已获得详情：半透明深色遮罩、白色圆角弹窗，圆形徽章、稀有度、标题、达成条件、获得日期及橙色分享按钮。
- 未获得详情：同一弹窗结构，浅色锁定徽章、条件说明、60% 示例进度条、浅色继续按钮及锁。
- Figma 的图片里浣熊 emoji 呈现依赖字体/平台，不能仅凭本机 emoji 字形推断稿件被改过。

## 必须保留的原版动效

基线源码：`MakePreview/src/app/components/BadgesScreen.tsx`（`WebDemo` 中也保存了同类实现）。

| 元素 | 原版行为 |
| --- | --- |
| hero 整体 | opacity 与 y 入场，0.5 秒 |
| 背景光斑 | x / y / opacity 循环，8 秒和 10 秒 |
| hero 钻石 | rotate / scale 循环，3 秒 |
| 计数和进度 | 缩放淡入、进度宽度 1.2 秒展开 |
| 筛选按钮 | 点击缩放 0.94，活动阴影过渡 |
| 徽章列表 | layout + AnimatePresence，0.35 秒入场，逐项 0.04 秒延迟；退出缩放淡出 |
| 徽章卡片 | 点击缩放；桌面 hover 上移；图标 hover 摇摆 |
| 详情遮罩 | opacity 淡入淡出，0.2 秒 |
| 详情卡 | scale / opacity / y，spring stiffness 320、damping 26 |
| 详情徽章 | scale 0、rotate -90 至正常，spring stiffness 200、damping 14 |
| 已获得详情光晕 | scale / opacity 循环，2.4 秒 |
| 锁定进度 | 0.9 秒展开，0.3 秒延迟 |

`MakePreview/MyPlansScreen.tsx` 的默认 tab 错写为 `All`，而枚举值是中文，复用时需修为「全部」，否则初始筛选会错误落到完成项。

## 验收边界

本记录先完成参考画板、素材和动效基线核实；后续实现和验收记录见下一节。全量 App 的逐画板清单尚未完成，不能将本模块的检查推及所有页面。


## 用户最终确认后的增量实现

本节对应用户确认：Sarah Chen 个人主页、保留徽章和原有动效；第三个 Tab 叫「项目」，内容采用「我的计划」稿；删除日历入口；其余页面不另行改版。

相关完整画板共 6 个：个人主页、徽章墙、已获得徽章详情、未获得徽章详情、我的计划、已保存的帖子。另 1 个日历画板明确排除；「项目」复用「我的计划」而不另算一张 Figma 画板。好友、AI 设置已有实现，但本记录未取得其独立 Figma 画板证据，不纳入已核实数量。

- 无原生连接的 Figma 预览保留原七枚可横滑已获得徽章，默认视口展示约五枚；手机内按真实解锁结果显示。完整徽章墙仍保留原 12 枚目录。
- 个人「我的计划」与第三个 Tab 共用项目路由；计划数量共用同一个真实状态 selector。
- 项目保留定稿图片、跨卡片宽度进度条、更多入口和暂停／继续按钮。暂停通过 native bridge 写入计划本身，旧版 JSON 自动解码为未暂停，保存失败回滚。
- 项目详情和徽章详情层级在浮动底栏之上，避免底部操作被遮挡或误点 Tab；徽章列表预留底栏滚动空间。
- 原徽章所有 motion 节点、AnimatePresence 和动画参数保留；拍摄流程本轮没有删除任何动画节点或动画属性。MakePreview 与当前主线已有的方案轮播、AR 和成功页差异另行记录，未在这次页面调整中重写。
- 项目页没有导入日历组件，也没有日历按钮；第三个 Tab 不再挂载社区页面。

数据边界：Sarah 身份、头像、加入时间和等级条仍是用户确认保留的 Figma 展示内容。2026-10-21 增量已将手机内个人统计、收藏数量及两项有依据的徽章解锁接入真实状态；其余徽章规则尚未实现，详见末节。项目列表使用真实原生计划和日程；空状态不填造假的示例计划。无原生 bridge 的浏览器预览保留 Figma 示例统计和徽章获得状态，不代表手机内真实用户的成就。

Web 打包通过，仅有主包大小提示；项目 selector 的空、进行中、暂停、待完成照、预定、完成和唯一 key 检查通过。新构建运行验证见下节。


### 新构建验证（2026-10-20）

- Scheme: SmartPaw；Debug；iPhone 16 / iOS 18.5。命令为 xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw -configuration Debug -destination 'platform=iOS Simulator,id=FA63A134-783E-4983-A62C-08CA35AF70F8' -derivedDataPath /tmp/smartpaw-figma-20261020 -resultBundlePath /tmp/smartpaw-figma-20261020-results.xcresult test。
- 编译、安装成功。全量 72 项中 66 项通过、6 项测试失败（共 15 个断言失败）；失败均位于照片识别／定位质量相关测试。不得将本次 UI 与暂停功能通过扩写成全 App 通过。
- 新增 4 项回归全部通过：旧 JSON 解码、暂停/恢复重启持久化且保留进度、过期 ID/完成计划拒绝、保存失败回滚。
- 独立 selector 检查通过：空列表、进行中 50%、暂停、全部步骤完成后待完成照、预定、完成及唯一 key。
- 新构建在独立模拟器 DECE4A2E-103D-4BB6-9CA0-06F902AA8C7B 中验证，避免与原生测试进程争用同一个 App。
- 已实际打开个人页、徽章墙、已获得详情、未获得详情；详情位于底栏上方，遮罩可关闭。截图见 verified-20261020/simulator。
- 头像来自 Figma 独立节点 `115:19695` 的 PNG 3x 导出，实际 432 × 432；运行时未替换成简化 SVG。来源及 SHA-256 见同目录 `profile-avatar-source.md`。最终个人页截图为 `simulator/profile-final.png`，计划数为原数据的 0；旧 `profile.png` 不是最终头像证据。
- 为验证非空项目，临时注入进行中、暂停、预定和完成各一个项目。已在模拟器实际点击暂停和继续，并读取持久化 JSON 验证 `isPaused` 从 false → true → false，已完成步骤始终为 3/5；在暂停状态重启 App 后，界面仍显示已暂停和 60%。
- 已实际打开进行中和预定项目详情并关闭；详情覆盖浮动底栏，预定项目的「标记计划完成」按钮完整可见。已完成筛选仅显示已完成项目。未在本次 UI 验收中重复执行步骤完成、完成照保存或完成日程操作，不能将这些路径列为新增运行验证。
- 临时数据验证期间的 `projects-fixture*.png`、`profile-fixture.png` 仅是测试数据证据。结束后已停止 App，按备份清单恢复原 JSON，移除原先不存在的测试 backup，并确认 SHA-256 与备份一致（`4e058467b4820e87c66f96f09835d7cb0a1363fdce9984429e2a761afeb7d82c`）。重启后的个人页计划数为 0，临时项目没有留给用户。
- 独立只读核对确认 `dist` 与 `Resources/FigmaMakeLatestWeb` 的 index 和 JS 字节一致，均引用 `index-Cj5Dm-OI.js`，头像原图已内联；最终 JS 没有「日历」。
- 模拟器自动 scroll/drag 没有产生可靠的触摸滚动结果，因此另用临时 Vite harness 渲染真实 `MyPlansScreen` 做浏览器验证：8 张卡片的列表 clientHeight 842、scrollHeight 1646，滚到底后 scrollTop 803.5；5 条长步骤的详情 clientHeight 637、scrollHeight 1150，滚到底后 scrollTop 513.5，第 5 步末尾可见。临时文件和服务已清理。该证据证明网页容器可滚动，不替代 iOS 实机手势验收。详情关闭按钮随内容滚动是现有行为。

识别失败项：
- testBundledCoreMLSegmentationModelIsUsableInScanPipeline
- testVisionScanServiceBuildsBaselineForIndependentPhotos
- testVisionScanServiceScansBundledIndependentPhotoWithARHints
- testYOLOSegmentationEvaluationDatasetReportsScenarioHitRate
- testYOLOSegmentationModelRecognizesNewNonVideoImages
- testYOLOSegmentationObjectLevelEvaluationReportsTargetRecallAndLocalization

完整日志：/tmp/smartpaw-figma-20261020-test.log；结果包：/tmp/smartpaw-figma-20261020-results.xcresult。

## 最终范围复核（2026-10-21）

本节补充当前源码和本轮浏览器验证的结果。前节 2026-10-20 的构建、测试和模拟器截图属于当时版本，不能视为 2026-10-21 变更后的完整运行验收。本轮最终复核仅修改本文档，没有改业务代码、重建 dist 或更新 App 内打包资源。

### 已核实的入口和界面范围

| 用户确认项 | 当前结果 | 证据边界 |
| --- | --- | --- |
| Sarah Chen 个人主页及徽章 | 个人页使用 Figma 导出头像、Sarah Chen 身份和徽章条；查看全部进入徽章墙，单枚徽章进入对应详情 | 当前源码与 390 × 844 浏览器交互已核实；身份和等级条仍为固定设计内容 |
| 第三栏为「项目」 | `BottomNav` 第三个非相机入口标为「项目」，`App` 挂载 `MyPlansScreen`；个人页「我的计划」指向同一 Tab | 路由源码已核实；不是单独保留另一套社区或原「项目」分组界面 |
| 内容采用「我的计划」稿 | 保留摘要、四个筛选、独立卡片图片、状态标签、跨卡片宽度进度条和暂停／继续按钮；标题为「项目」 | 源码与此前模拟器证据支持结构；当前全部数据状态未重新逐项做像素比对 |
| 不要日历 | 当前启动路径与前端路由均没有日历入口、日历按钮或 `CalendarScreen` 导入 | 从 `src/main.tsx` 遍历静态本地依赖共 22 个模块，日历和 `CommunityScreen` 均不在可达依赖闭包；`SmartPawApp` → `RootView` 仅挂载 `CurrentFigmaMakeWebView` |

`CalendarScreen.tsx` 和通用 `components/ui/calendar.tsx` 源文件仍在仓库，当前没有被运行入口引用。它们是不可达旧组件，不列为用户仍能打开的页面。原生模型中用于计算提醒日期的 `Calendar` 也不是日历界面。

### 真实数据与徽章规则

- 手机内已追踪物品和已整理空间读取 `profileStats`，旧状态缺字段时分别从空间物品和有已完成方案的空间数计算；已获得徽章数由同一徽章 selector 计算，收藏数读取 `favorites`。
- 原生 bridge 存在而状态尚未返回时显示零统计，不会短暂显示 248 / 12 / 7。只有无原生连接的浏览器预览使用这些 Figma 示例值和七枚示例已获得徽章。
- 12 枚徽章的名称、图标、条件文案、稀有度与 Figma 原目录一致，没有替换为原生旧成就目录。手机内不展示编造的获得日期或无数据依据的百分比。

| 徽章 | 当前真实规则 |
| --- | --- |
| 整洁小浣熊 | 已保存的完成方案数大于零时解锁，作为「完成第一个整理分区」的现有可验证依据 |
| 闪亮魔法师 | 已整理空间数达到 5 时解锁；未解锁进度按真实空间数 / 5 计算 |
| 整理冠军、涅槃凤凰 | 尚未实现连续整理 10 / 30 天规则，保持锁定 |
| 绿手指、收纳盒大师 | 尚未记录捐赠数量、收纳工具使用数量，保持锁定 |
| 一击即中、闪电快手 | 尚未有匹配条件的截止时间／实际耗时记录，保持锁定 |
| 钻石级、心有灵犀 | 尚未实现真实等级成长和 AI 建议采纳计数，保持锁定 |
| 晨光型选手、分享浪潮 | 尚未接入晨间完成条件和分享次数累计，保持锁定 |

因此徽章的展示、筛选和详情路径已连接，完整 12 项成就规则尚未实现，不能称为全部徽章功能已完成。

### 动效保留证据

- 当前 `BadgesScreen.tsx` 与 `MakePreview/src/app/components/BadgesScreen.tsx` 逐项提取对照：16 个 `motion` 元素、43 组 `initial` / `animate` / `exit` / `transition` / `whileTap` / `whileHover` 参数保持一致。对照仅归一化筛选局部变量改名，并允许总进度条的空目录除零保护。
- 徽章 hero、光斑、钻石、计数、筛选、列表进出、详情弹入、光晕和进度动画均仍有原节点及参数；未用静态截图代替 UI。
- 原版及当前 `MineScreen`、`MyPlansScreen`、`BottomNav` 均没有 `motion` 元素，不把它们原本不存在的动画列为本轮删除。
- 本轮浏览器运行中 hero 钻石的 computed transform 在相隔 500 ms 的两次取样间发生变化，确认动画实际执行。此证据针对 Web 页面，不等同于全部 iOS 动效、帧率、触觉反馈或拍摄流程的验收；拍摄主线由独立核查记录覆盖。

### 本轮验证及未测范围

- 最后一次 Web build 成功，输出 `/tmp/smartpaw-ui-interaction-audit-build-2`；仅有包大小提示。本轮最终只读复核没有重跑构建或覆盖共享 dist。
- Chrome / Playwright 在 390 × 844 视口、模拟原生 bridge 的状态下验证：个人三列统计为 3 / 1 / 1、单枚徽章直接打开对应详情、锁定筛选保留全部 11 枚未解锁徽章、闪亮魔法师显示真实 20% 进度、没有依据的整理冠军不显示假进度、原生状态等待期间统计保持零。
- 轻量 selector 检查覆盖零个、一个、五个已整理空间，解锁数分别为 0 / 1 / 2；目录始终为 12，未支持条件保持锁定，真实状态没有演示获得日期。
- 临时浏览器服务已停止。浏览器使用注入状态，只证明页面的数据选择和交互，不能证明 Swift 持久化、相机或系统分享已通过。
- 本轮个人／徽章增量没有重做新 App 的模拟器安装、实际触摸滚动、系统分享面板、VoiceOver、动态字体、多机型布局或离线重启测试。项目的步骤完成、完成照保存、计划归档路径仍需按最终打包版本进行运行验收，不能由源码接线推定成功。

### 仍可实际抵达的限制

- 项目卡片的「更多」图标目前调用与卡片相同的打开详情操作，没有独立操作菜单（`MyPlansScreen.tsx:127`）。
- 项目摘要仍写「本周」，但活动数和预计用时没有按周筛选，较早的未完成项目也会计入（`MyPlansScreen.tsx:42`、`:43`、`:109`）。
- 已完成项目卡片目前显示「已完成 · 预算分钟数」，尚未按 Figma 稿显示完成日期及实际用时（`MyPlansScreen.tsx:124`）；不能把预算当作实际耗时。
- 待完成照状态的「继续」会打开包含「选择完成照并保存」的详情，路径可达，但按钮没有直接表明接下来要补完成照（`MyPlansScreen.tsx:129`、`:140`）。
- 个人页「帮助与反馈」「退出登录」目前仅弹出未接入提示；真实账号、帮助反馈流程和等级成长不在已完成范围（`MineScreen.tsx:51`、`:52`）。

上述限制均来自当前可达页面，不包含未挂载的旧社区、日历或其他历史组件。当前结论是指定 UI 范围和路由已按确认方向连接，仍存在明示的功能空缺与运行验证范围；不据此宣称全 App 已完成或已达到 App Store 审核标准。
