# 灵爪收纳提交准备验收 · 2026-10-20

**结论：本地核心流程已修复并构建验证，尚未达到可提交 App Store 审核的条件。** 发行账号、模型授权、公开隐私/支持资料、上传工具链和真机验收仍有阻塞。未上传 TestFlight，未提交审核。

仓库：https://github.com/Qszjlzz/LingZhuaShouNa 。本地分支：`codex/app-store-readiness-20261020`。改动尚未提交或推送；保留了已有 README 工作及 `WebDemo/screenshots/filter-updated.html`。

## 已落实的行为

- 首次安装只有一个空空间；物品、完成次数、日程、徽章和本机记录以实际保存数据为准。移除主入口中的演示物品、预制整理效果和虚假社交统计。
- 每批照片按 capture ID 等待识别；取消或退出后旧结果失效。识别为空可以手动补录，文字方案不编造 AR 坐标。
- 实际生成方案后才进入步骤引导。每一步保存成功才推进；全部步骤完成且实际完成照写入成功后才归档。写盘失败回滚并允许重试，避免假完成和假成就。
- 修复相机重复启动、拒绝权限后长时间等待、选择照片过久导致网页超时但原生已保存的问题；完成照页有退出入口。修复底部导航挡住添加表单保存按钮的问题。
- 默认关闭云端 AI；启用和测试前要求明确同意，使用 HTTPS，密钥只放 Keychain。移除包内默认密钥配置和自动导入。灵感页为 4 条原创离线技巧、本机记录和收藏。
- 补齐隐私 manifest、版本/显示名、用途说明、网页完整构建同步脚本和提交门禁。Release 排除六张来源未核的评测图片，图标无 alpha 通道。

## 实际验证

| 项目 | 结果与范围 | 证据 |
| --- | --- | --- |
| 功能回归 | 50/50 通过；命令显式排除 14 项模型资源/真实图片精度测试，不能称全量通过 | [结果摘要](evidence/functional-test-summary.json)、[精确命令](recognition-validation.md) |
| 本轮复核功能回归 | 53/53 通过；在同一排除范围内重新执行，包含扫描确认后取消回滚、云端同意、失败写盘、重置和持久化等回归；仍不包含模型精度门槛 | [复核摘要](evidence/functional-recheck-2026-10-20.json)、`/tmp/SmartPawFunctionalLatest/Logs/Test/Test-SmartPaw-2026.10.20_13-23-25-+0800.xcresult` |
| 取消回归 | 另一次运行 1/1 通过，覆盖单张/批量和 Task/入口取消组合 | [结果摘要](evidence/scan-cancel-test-summary.json) |
| 网页桥接回归 | 用可控计时器验证：照片选择期间不提前超时，成功后返回保存回执；取消会拒绝请求；普通请求保留超时 | 本次 Node 24 实际运行输出 `PASS: delayed picker save, picker cancel, ordinary request timeout` |
| 网页生产构建 | Vite 构建成功；dist 与包内资源逐字节一致。存在大于 500KB 的 chunk 警告 | [包核验与 SHA-256](evidence/final-package-check.json) |
| Release Simulator | `BUILD SUCCEEDED`，安装并启动 iPhone 16 Pro Max / iOS 18.5 新建验收模拟器 | `/tmp/smartpaw-release-final.log` |
| iOS Release archive | `ARCHIVE SUCCEEDED`；**未签名**，Xcode 16.4 / iOS 18.5 SDK，**不可上传** | `/tmp/SmartPaw-Review-Final-20261020.xcarchive`、`/tmp/smartpaw-device-archive-final.log`、[包核验](evidence/final-package-check.json) |
| 静态检查 | `git diff --check`、Ruby 生成器语法、隐私 plist lint 通过；生成器同步 Release 排除规则 | 本次实际执行 |
| 提交门禁 | **2 FAIL、2 WARN**：旧 SDK、AGPL 权重；本地 ignored 密钥配置和缺少权重许可证 | [完整门禁输出](evidence/preflight-final.txt) |

本轮复核时，表中原 `/tmp/SmartPaw-Review-Final-20261020.xcarchive`、`/tmp/smartpaw-release-final.log` 和 `/tmp/smartpaw-device-archive-final.log` 已不存在。归档与 Release 结果是此前保留的汇总记录，不能代替当前改动后的最终产物核验。功能复核的最新 53 项 xcresult 仍可读取；此前 51 项记录保留作历史证据。

完整功能 xcresult：`/tmp/smartpaw-functional-tests/Logs/Test/Test-SmartPaw-2026.10.20_00-59-02-+0800.xcresult`；取消 xcresult：`/tmp/smartpaw-functional-tests/Logs/Test/Test-SmartPaw-2026.10.20_01-01-05-+0800.xcresult`。两包均由 `xcresulttool` 核对为 `Passed`，并保留摘要。原生逻辑测试早于最后网页/预览交互修复；最后改动另有 Release 构建和模拟器复验。

## 模拟器人工验收

新建专用 `SmartPaw App Store Review` 模拟器（`3895F5DA-BA7F-4076-953E-C9AD0762990F`），未清除用户原设备数据。

1. 首次启动核对空空间、分类空态、云端默认关闭且同意框未勾选。
2. 拒绝相机后，从系统相册导入书桌测试图。本地返回 4 个候选；确认区域、生成 3 条原生步骤，逐条保存完成。
3. 从相册选择同一张 fixture 作为完成照，成功显示对比页；退出及重启后恢复照片和完成次数。共执行两轮，持久化为 2 条完成方案、每条步骤均 done、无活动方案，前后照片存在。
4. 核对分类实际数量；在书籍分类手动添加 `book`，保存成功、书籍数量由 1 变 2。后续新扫描按当前批次替换识别物品，完成历史保留。
5. 检查 4 条本地技巧及展开内容。最终 Release 再安装后，拒绝相机立即显示拒绝说明、相册和退出入口，无此前透明白屏等待。

**两次使用相同测试照片只验证流程、回执与持久化，不证明房间已整理、自动画质判断或识别精度。** 截图是工程验收证据，不是可直接上传的商店宣传素材；素材版权仍按许可清单处理。

- [原生步骤](evidence/01-native-plan.png)
- [重启恢复完成记录](evidence/02-persisted-fixture-completion.png)
- [本地灵感](evidence/03-local-inspiration.png)
- [真实分类数](evidence/04-real-category-counts.png)
- [手动添加成功](evidence/05-manual-item-saved.png)
- [完成照保存成功回执](evidence/06-fixture-comparison-saved.png)
- [最终版本拒绝相机状态](evidence/07-camera-denied-final.png)
- [持久化状态摘要](evidence/persisted-fixture-summary.json)

## 未通过与待完成

1. **开发者发行资格**：用户确认尚无付费 Apple Developer 账号；发行证书、App Store Connect App、协议和签名均待准备。
2. **上传工具链**：Apple 自 2026-04-28 要求 Xcode 26 及 iOS 26 SDK 以上。本机 macOS 15.5 / Xcode 16.4；现有归档 SDK 为 iphoneos18.5，且未签名。
3. **版权**：Ultralytics 元数据含 AGPL-3.0，用户尚无商业许可。需要取得适用授权或替换权重；EdgeSAM、MobileCLIP、DeepLab 及其他素材来源也待核。[许可清单](model-license-inventory.md) 中未用同名开源仓库许可证冒充当前权重证据。
4. **公开资料**：用户确认尚无正式支持邮箱、隐私政策和支持页；草稿不能替代真实 HTTPS 页面。云服务的主体、处理地区、留存/删除与 App Privacy 答案须按实际服务确认。
5. **识别与真机验收**：原评测未通过：6 张图 16 个标注目标匹配 11 个，召回 69%、匹配目标平均 IoU 0.643，衣柜/车库有漏检。没有删掉或降低原精度断言。当前配对 iPhone 的系统版本超出 Xcode 16.4 支持，未验证真机相机、AR、后台恢复、低存储或长时间使用；不能由模拟器代替。
6. **发行内容复核**：源码仍有不可达旧组件及少量远程 Unsplash/style 资源，Vite 构建不等于全项目 TypeScript 类型检查。主路径已收窄；上线宣传只描述经验证能力，外部素材、远程资源与本地占位需在真机无网络场景复核。

本地 ignored `Resources/llm-defaults.json` 含曾使用的服务凭证，已从工程、生成器和归档排除；没有读取到报告或公开其值。持有人应撤销曾用密钥并清理本地旧配置。

下一步按 [从 BLOCKED 到可提交](next-steps.md) 准备发行账号、工具链、许可、公开资料，再做真机与 TestFlight 验收。账号注册、付款、签约及公网发布不能由本次仓库修复代替。
