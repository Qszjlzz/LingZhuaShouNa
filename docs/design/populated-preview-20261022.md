# 最终稿区域与有数据展示版

2026-10-22。用户指定只参考附件截图中的 Page 1 左侧竖排最终稿，以及左侧相邻社区稿；右侧 Frame 7、比赛展板和散落旧稿不纳入本轮。本轮沿用现有 React + WKWebView 页面结构，补齐数据和详情入口，不宣称全应用已完成像素级复刻。

## 可直接打开的设计来源

| 部分 | 已核对 Figma 节点 | 对应运行页面 |
| --- | --- | --- |
| 详细整理流程 | [2261:6479](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2261-6479)，其中化妆品步骤 [2276:3547](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2276-3547) 已重新点选确认 | `ShootFlow` 方案、分区、执行；个人页的“浏览整理流程”可直接进入已有样例 |
| 空间地图 | [2283:6711](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2283-6711) | `SpatialScreen`，床、厨房、茶几，以及不同维护时间 |
| 分类组 | [2283:9423](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2283-9423) | `ClassificationScreen`、`BooksCategoryScreen`，搜索、分组、编辑、添加 |
| 有数据的分类首页 | [2283:6715](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2283-6715)，390 × 1118 | 八个非空分类，最近物品；书籍含小说、学习、哲学 |
| 项目组 | [2381:8080](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2381-8080)，5051 × 1419 | `MyPlansScreen`，进行中、暂停、预定、完成及详情。沿用用户此前确认的底栏“项目”；不恢复独立日历入口 |
| 个人组 | [2284:11375](https://www.figma.com/design/cHyKGPXFlSnNcjBWw9MNxE/ui%E7%95%8C%E9%9D%A2?node-id=2284-11375)，当前最终区可见四张手机稿 | `MineScreen`、`BadgesScreen`、获得和锁定徽章详情 |

来源画布截图位于 `app-analysis/figma-reference/populated-20261022/`。截图包含 Figma 选区和尺寸，用于确认设计来源，不代表运行时视觉验收。

## 数据与边界

- 样例独立存为 `smart-paw-presentation-state.json`，照片独立目录 `SmartPawPresentationImages`。个人页下方“展示数据”可切换“样例 / 我的数据”。Debug 首次默认样例，Release 首次默认我的数据。
- 样例有三个空间、64 件可编辑物品、三个进行中或暂停项目、一个预定项目、三条完成记录、四个收藏和三个已关注作者。书籍按小说、学习、哲学分组；分类显示最终稿的八类。
- 个人页的 248 件 / 12 空间 / 7 徽章是明确标注的设计样例统计；物品与项目页使用实际样例记录，数量并不冒充个人真实档案。
- AI 地址、模型等非秘密配置共享，Key 保留在原系统 Keychain。切换数据不重新导入 Key，也不自动发起付费生图或授权上传。
- 演示模式的恢复只恢复样例；真实数据模式的删除仍是用户主动触发的原有删除流程。
- 本轮补数据没有解决真实照片识别准确率、区域定位和生图服务超时，不能据此认定达到 App Store 上架或 90% 识别目标。

## 本轮验证

- 原生 `PresentationModeTests` 最终 **9/9 通过**，覆盖样例与真实文件隔离、切换持久化、失败回滚、设置共享但不保存 Key、临时扫描清理、旧样例分类迁移及幂等。结果：`/tmp/smartpaw-presentation-migration-20261022.xcresult`。
- 网页执行流程回归 **15/15 通过**；最终网页资源为 `Resources/FigmaMakeLatestWeb/assets/index-Bzb8cncK.js`。模拟器、真机 Debug 构建均成功，`git diff --check` 通过。
- 实际点选验证：三空间地图、64 件物品和八个非空分类、书籍详情三组、项目暂停与恢复、个人样例统计、7/12 徽章与 60% 锁定详情、样例与我的数据双向切换、方案照片、24 件样例物品的分区页、执行页及“下一步”推进。
- 验收时修复两项问题：中途安装的旧样例十分类自动迁移到最终八分类；图片组件在异步图片到达后清除先前失败状态，恢复方案与执行照片。
- 运行截图位于 `outputs/populated-preview-20261022/`，与 Figma 来源截图分开保存。截图来自 iPhone 16 Pro 模拟器，不冒充实机截图或逐像素验收。
- 手机最终安装为 **1.0.0(5)**，`devicectl info apps` 已核对版本。安装后最初因设备锁屏无法启动；20:09:27 重查时已成功启动 `com.qszjlzz.smartpaw`。证据为 `/tmp/smartpaw-install-v5-20261022.json`、`/tmp/smartpaw-installed-v5-20261022.json`、`/tmp/smartpaw-launch-v5-recheck-20261022.json`。
- 本轮没有调用付费生图，打包产物中没有 `image-generation.json`。不重复执行已知包含六项历史失败的全量识别测试。照片使用现有小尺寸设计素材；分区样例缺少真实识别坐标时显示一个收纳区域，尚未证明真实照片定位效果或全应用像素一致性。
