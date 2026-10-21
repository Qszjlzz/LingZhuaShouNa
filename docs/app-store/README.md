# App Store 提交准备

这组文件记录 `SmartPaw`（显示名：灵爪收纳）在 2026-10-20 的提交审计。它们描述可由仓库证明的事实；方括号内容必须由开发者、法务或 App Store Connect 管理员补齐，不能直接当作已发布信息。

当前接手入口为 [HANDOFF.md](../../HANDOFF.md)。这些资料保留历史提交准备背景；后续用户将当前优先事项明确为 Figma 手机 UI 还原，并以“项目”替换底栏社区、移除日历。下文关于可达“灵感”页等内容属于当时审计，不能覆盖当前路由事实。

| 文件 | 用途 |
| --- | --- |
| [apple-rules.md](apple-rules.md) | Apple 官方规则、适用结论和核验日期 |
| [metadata-draft.md](metadata-draft.md) | App Store Connect 元数据草稿和待填项 |
| [privacy-support-draft.md](privacy-support-draft.md) | 隐私政策、支持页和云端 AI 披露草稿 |
| [review-notes.md](review-notes.md) | 给 App Review 的测试路径、限制和提交前清单 |
| [model-license-inventory.md](model-license-inventory.md) | 包内模型、代码和图片的许可证据与阻塞项 |
| [validation-2026-10-20.md](validation-2026-10-20.md) | 最终代码、构建、测试、模拟器证据及未通过项 |

## 当前判定

仓库已经有 Release 配置、相机/照片用途说明和 Required Reason API manifest，但当前工作站的 Xcode 16.4 不能产生符合 2026-04-28 起要求的上传包；必须在支持 Xcode 26 的 macOS 环境重新构建和签名。当前没有付费 Apple Developer 发行资格、Ultralytics 模型商业许可、公开隐私政策 URL、支持邮箱或支持 URL，因此提交状态明确为 **BLOCKED**。包内其他模型和图片的原始许可仍待核；详见 [next-steps.md](next-steps.md)。

当前可达的“灵感”页是 4 条原创离线整理技巧，完成成果和收藏只保存在本机，没有线上社区或用户内容外发入口；但 `FigmaMakeLatest-v3/src` 和归档 Web bundle 仍包含 `images.unsplash.com` 的遗留方案/工具图片、品牌购买链接和用户可填的第三方 AI endpoint。提交前应确认主流程在无网络时仍可完成，遗留远程图片有本地占位/错误态，并在隐私政策中说明可选云端 AI 的数据流；不能把任意第三方服务的可用性写成应用自有服务承诺。

## 使用方式

先运行 `scripts/build-bundled-web.sh` 生成并同步内嵌网页，再运行 `scripts/release-preflight.sh`，最后在支持 Xcode 26 或更高版本的机器执行 Release archive。构建脚本需要 Node/npm 和 Python 3；门禁需要 Xcode 命令行工具和 Python 3。门禁实际解析隐私 plist、检查网页入口引用，并在 `dist` 存在时逐文件比较构建与内嵌资源。它不能替代真机验收、隐私问卷、版权核验、App Review 或账号配置；`dist` 与内嵌资源一致也不能单独证明当前源码已重新构建。

脚本语法、隐私资源阶段和门禁正反例的本轮结果见 [脚本复核证据](evidence/release-script-validation-2026-10-20.json)。其中模拟的 Xcode 26/27 输出只验证版本判断，不代表本机已升级或产生合规归档。

在本次审计工作站（Xcode 16.4）运行时，预期至少有 2 个 FAIL（Xcode/iOS 26 SDK、Ultralytics AGPL 模型）和 2 个 WARN（本地 ignored 配置、缺少随权重保存的许可证文件）；这就是当前 BLOCKED 状态的可重复证据。
